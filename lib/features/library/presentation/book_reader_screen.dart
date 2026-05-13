import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../data/library_repository.dart";

/// Full-screen reader: [TextPainter] runs only when extending page boundaries
/// (current page + optional prefetch), never for the whole book at once.
class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.item,
    required this.onLoadBookContent,
  });

  final MediaListItem item;
  final Future<String> Function(MediaListItem item) onLoadBookContent;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  static const _prefsNs = "book_reader_v1";

  late final PageController _pageController;

  String? _text;
  Object? _loadError;
  bool _loading = true;

  /// Start index of page i. Page i ends at starts[i+1] or EOF.
  /// Built lazily: always starts as [0].
  List<int> _pageStarts = <int>[0];

  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);

  Timer? _persistTimer;

  /// True once we know the last page begins at [_pageStarts.last] and ends at EOF.
  bool _enumeratedToEnd = false;

  String? _layoutSignature;

  int _savedCharOffset = 0;

  String? _splitScheduledForSig;

  double? _layoutMaxW;
  double? _layoutMaxH;

  /// [TextPainter] boundary cache: layout + start offset → exclusive end.
  final Map<String, int> _pageMeasureCache = <String, int>{};

  String get _offsetKey => "${_prefsNs}_off_${widget.item.id}";
  String get _fileKey => "${_prefsNs}_file_${widget.item.id}";

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bootstrap();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    unawaited(_writeOffsetToPrefs(_savedCharOffset));
    _pageIndex.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final boundFile = widget.item.mediaFileId ?? "";
      final storedFile = prefs.getString(_fileKey) ?? "";
      if (storedFile != boundFile) {
        await prefs.setString(_fileKey, boundFile);
        await prefs.remove(_offsetKey);
        _savedCharOffset = 0;
      } else {
        _savedCharOffset = prefs.getInt(_offsetKey) ?? 0;
      }

      final text = await widget.onLoadBookContent(widget.item);
      if (!mounted) {
        return;
      }
      setState(() {
        _text = text;
        _loading = false;
        _loadError = null;
        _layoutSignature = null;
        _pageStarts = <int>[0];
        _enumeratedToEnd = false;
        _splitScheduledForSig = null;
        _layoutMaxW = null;
        _layoutMaxH = null;
        _pageMeasureCache.clear();
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
  }

  void _persistOffsetNow(int charStart) {
    _savedCharOffset = charStart;
    _persistTimer?.cancel();
    _persistTimer = null;
    unawaited(_writeOffsetToPrefs(charStart));
  }

  Future<void> _writeOffsetToPrefs(int charStart) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_offsetKey, charStart);
  }

  /// Writes [charStart] after the user stops flipping for a short time (avoids prefs I/O every page).
  void _persistOffsetDebounced(int charStart) {
    _savedCharOffset = charStart;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 450), () {
      _persistTimer = null;
      final target = _savedCharOffset;
      unawaited(_writeOffsetToPrefs(target));
    });
  }

  TextStyle _bodyStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return base.copyWith(height: 1.35);
  }

  /// [TextScaler.hashCode] is not stable across frames; use scale ratio for layout identity.
  String _layoutScaleKey(TextStyle style, TextScaler scaler) {
    final fs = style.fontSize ?? 14.0;
    if (fs <= 0) {
      return scaler.scale(14.0).toStringAsFixed(3);
    }
    final r = scaler.scale(fs) / fs;
    return r.toStringAsFixed(3);
  }

  /// Slightly tighter box than [Text] in [_BookReaderPage] so pagination never
  /// assumes one page can hold more than actually fits (which used to set
  /// [_enumeratedToEnd] too early and freeze [PageView] at two pages).
  (double, double) _paintExtent(double layoutMaxW, double layoutMaxH) {
    final w = math.max(1.0, layoutMaxW - 2.0);
    final h = math.max(1.0, layoutMaxH - 14.0);
    return (w, h);
  }

  int _itemCountForPageView(String text) {
    if (text.isEmpty) {
      return 1;
    }
    if (_enumeratedToEnd) {
      return math.max(1, _pageStarts.length);
    }
    if (_pageStarts.isEmpty) {
      return 1;
    }
    final last = _pageStarts.last;
    if (last >= text.length) {
      return math.max(1, _pageStarts.length);
    }
    return _pageStarts.length + 1;
  }

  /// When [itemCount] shrinks (e.g. placeholder revealed EOF), [PageController] can
  /// point past the last page; fix geometry and persist offset.
  void _clampPageToBounds(String text) {
    if (!mounted || text.isEmpty || !_pageController.hasClients) {
      return;
    }
    final n = _itemCountForPageView(text);
    final maxIdx = math.max(0, n - 1);
    final cur = _pageIndex.value;
    if (cur <= maxIdx) {
      return;
    }
    _pageIndex.value = maxIdx;
    _pageController.jumpToPage(maxIdx);
    if (maxIdx < _pageStarts.length) {
      _persistOffsetDebounced(_pageStarts[maxIdx]);
    }
  }

  void _scheduleLayoutSync(
    BuildContext context,
    String text,
    double maxW,
    double maxH,
  ) {
    if (maxW <= 0 || maxH <= 0) {
      return;
    }

    if (text.isEmpty) {
      if (_splitScheduledForSig == "empty") {
        return;
      }
      _splitScheduledForSig = "empty";
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _splitScheduledForSig = null;
        if (!mounted) {
          return;
        }
        setState(() {
          _pageStarts = <int>[0];
          _enumeratedToEnd = true;
          _layoutSignature = "empty";
          _pageIndex.value = 0;
        });
      });
      return;
    }

    final scaler = MediaQuery.textScalerOf(context);
    final style = _bodyStyle(context);
    final sig =
        "${text.length}_${maxW.round()}_${maxH.round()}_${_layoutScaleKey(style, scaler)}";

    if (sig == _layoutSignature &&
        _layoutMaxW == maxW &&
        _layoutMaxH == maxH &&
        _pageStarts.isNotEmpty) {
      return;
    }
    if (_splitScheduledForSig == sig) {
      return;
    }
    _splitScheduledForSig = sig;

    final anchor = _savedCharOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _splitScheduledForSig = null;
      if (!mounted) {
        return;
      }
      setState(() {
        _layoutSignature = sig;
        _layoutMaxW = maxW;
        _layoutMaxH = maxH;
        _pageStarts = <int>[0];
        _enumeratedToEnd = false;
        _pageMeasureCache.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final idx = _pageIndexForCharOffset(
          text,
          maxW,
          maxH,
          style,
          scaler,
          anchor,
        );
        _prepareNeighbors(text, maxW, maxH, style, scaler, idx);
        _pageIndex.value = idx;
        if (_pageController.hasClients) {
          _pageController.jumpToPage(idx);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _clampPageToBounds(text);
        });
      });
    });
  }

  /// Walk forward with [TextPainter] until [offset] lies on page p; return p.
  int _pageIndexForCharOffset(
    String text,
    double maxW,
    double maxH,
    TextStyle style,
    TextScaler scaler,
    int offset,
  ) {
    if (text.isEmpty) {
      return 0;
    }
    var o = offset.clamp(0, math.max(0, text.length - 1));
    _pageStarts = <int>[0];
    _enumeratedToEnd = false;
    var page = 0;
    while (true) {
      if (page >= _pageStarts.length) {
        if (_pageStarts.isEmpty) {
          return 0;
        }
        final last = _pageStarts.last;
        if (last >= text.length) {
          _enumeratedToEnd = true;
          return math.max(0, _pageStarts.length - 1);
        }
        final next = _measurePageEnd(
          text,
          last,
          maxW,
          maxH,
          style,
          scaler,
        );
        if (next >= text.length) {
          _enumeratedToEnd = true;
          return math.max(0, _pageStarts.length - 1);
        }
        _pageStarts.add(next);
        continue;
      }
      final start = _pageStarts[page];
      if (start >= text.length) {
        _enumeratedToEnd = true;
        return page;
      }
      final endExcl = _measurePageEnd(
        text,
        start,
        maxW,
        maxH,
        style,
        scaler,
      );
      if (endExcl >= text.length) {
        _enumeratedToEnd = true;
        return page;
      }
      if (o < endExcl) {
        return page;
      }
      if (page == _pageStarts.length - 1) {
        _pageStarts.add(endExcl);
      }
      page++;
    }
  }

  String _measureCacheKey(int start, double maxW, double maxH) {
    return "${_layoutSignature ?? ""}_${maxW.round()}_${maxH.round()}_$start";
  }

  int _measurePageEnd(
    String text,
    int start,
    double maxW,
    double maxH,
    TextStyle style,
    TextScaler scaler,
  ) {
    if (start >= text.length) {
      return text.length;
    }
    final (paintW, paintH) = _paintExtent(maxW, maxH);
    final cacheKey = _measureCacheKey(start, paintW, paintH);
    final cached = _pageMeasureCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    var end = endIndexForBookPage(
      text: text,
      start: start,
      maxWidth: paintW,
      maxHeight: paintH,
      style: style,
      textScaler: scaler,
    );
    end = math.min(text.length, math.max(start + 1, end));
    _pageMeasureCache[cacheKey] = end;
    return end;
  }

  /// Ensures boundaries include page [p] and prefetches [p±1] ends (cheap extra measures).
  void _prepareNeighbors(
    String text,
    double maxW,
    double maxH,
    TextStyle style,
    TextScaler scaler,
    int p,
  ) {
    _ensurePageMeasurable(text, p, maxW, maxH, style, scaler);
    if (p > 0) {
      _ensurePageMeasurable(text, p - 1, maxW, maxH, style, scaler);
    }
    _ensurePageMeasurable(text, p + 1, maxW, maxH, style, scaler);
  }

  /// Guarantee substring for page [targetPage] is defined (extend chain if needed).
  void _ensurePageMeasurable(
    String text,
    int targetPage,
    double maxW,
    double maxH,
    TextStyle style,
    TextScaler scaler,
  ) {
    if (targetPage < 0 || text.isEmpty) {
      return;
    }

    while (_pageStarts.length <= targetPage) {
      final s = _pageStarts.last;
      if (s >= text.length) {
        _enumeratedToEnd = true;
        return;
      }
      final e = _measurePageEnd(text, s, maxW, maxH, style, scaler);
      if (e >= text.length) {
        _enumeratedToEnd = true;
        return;
      }
      _pageStarts.add(e);
    }

    final start = _pageStarts[targetPage];
    if (start >= text.length) {
      return;
    }

    if (targetPage == _pageStarts.length - 1 && !_enumeratedToEnd) {
      final e = _measurePageEnd(text, start, maxW, maxH, style, scaler);
      if (e >= text.length) {
        _enumeratedToEnd = true;
      } else if (e < text.length && _pageStarts.length == targetPage + 1) {
        _pageStarts.add(e);
      }
    }
  }

  void _extendAllPagesToEnd(
    String text,
    double maxW,
    double maxH,
    TextStyle style,
    TextScaler scaler,
  ) {
    while (!_enumeratedToEnd) {
      final s = _pageStarts.last;
      if (s >= text.length) {
        _enumeratedToEnd = true;
        return;
      }
      final e = _measurePageEnd(text, s, maxW, maxH, style, scaler);
      if (e >= text.length) {
        _enumeratedToEnd = true;
        return;
      }
      _pageStarts.add(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: "Закрыть",
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.item.title),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: "Закрыть",
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.item.title),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _loadError.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _loadError = null;
                      _text = null;
                      _layoutSignature = null;
                      _pageStarts = <int>[0];
                      _enumeratedToEnd = false;
                      _splitScheduledForSig = null;
                      _pageMeasureCache.clear();
                    });
                    _bootstrap();
                  },
                  child: const Text("Повторить"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final text = _text ?? "";
    final style = _bodyStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    final pageCount = _itemCountForPageView(text);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: "Выйти из чтения",
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.item.title),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _pageIndex,
            builder: (context, pageIdx, _) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    _enumeratedToEnd
                        ? "${pageIdx + 1} / $pageCount"
                        : "${pageIdx + 1} / ?",
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const horizontalPad = 16.0;
                const verticalPad = 16.0;
                final maxW = constraints.maxWidth - horizontalPad * 2;
                final maxH = constraints.maxHeight - verticalPad * 2;

                _scheduleLayoutSync(context, text, maxW, maxH);

                if (text.isNotEmpty &&
                    (_layoutSignature == null || _layoutMaxW == null)) {
                  return const Center(child: CircularProgressIndicator());
                }

                return PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (i) {
                    _pageIndex.value = i;
                    if (i < _pageStarts.length) {
                      _persistOffsetDebounced(_pageStarts[i]);
                    }
                    final w = _layoutMaxW ?? maxW;
                    final h = _layoutMaxH ?? maxH;
                    if (w > 0 && h > 0) {
                      final lenSync = _pageStarts.length;
                      final enumSync = _enumeratedToEnd;
                      _ensurePageMeasurable(
                        text,
                        i + 1,
                        w,
                        h,
                        style,
                        scaler,
                      );
                      if (!mounted) {
                        return;
                      }
                      if (lenSync != _pageStarts.length ||
                          enumSync != _enumeratedToEnd) {
                        setState(() {});
                      }
                    }
                    scheduleMicrotask(() {
                      if (!mounted) {
                        return;
                      }
                      final lenBefore = _pageStarts.length;
                      final enumBefore = _enumeratedToEnd;
                      if (w > 0 && h > 0) {
                        _prepareNeighbors(text, w, h, style, scaler, i);
                        if (!_enumeratedToEnd &&
                            i == _pageStarts.length - 1 &&
                            i < _pageStarts.length &&
                            _pageStarts[i] < text.length) {
                          final endProbe = _measurePageEnd(
                            text,
                            _pageStarts[i],
                            w,
                            h,
                            style,
                            scaler,
                          );
                          if (endProbe >= text.length) {
                            _enumeratedToEnd = true;
                          }
                        }
                      }
                      if (!mounted) {
                        return;
                      }
                      if (lenBefore != _pageStarts.length ||
                          enumBefore != _enumeratedToEnd) {
                        setState(() {});
                      }
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      _clampPageToBounds(text);
                    });
                  },
                  itemBuilder: (context, i) {
                    if (text.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final w = _layoutMaxW ?? maxW;
                    final h = _layoutMaxH ?? maxH;
                    if (w <= 0 || h <= 0) {
                      return const SizedBox.shrink();
                    }
                    if (i >= _pageStarts.length) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) {
                          return;
                        }
                        _ensurePageMeasurable(text, i, w, h, style, scaler);
                        setState(() {});
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          _clampPageToBounds(text);
                        });
                      });
                      return const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final start = _pageStarts[i];
                    int end;
                    if (i + 1 < _pageStarts.length) {
                      end = _pageStarts[i + 1];
                    } else if (_enumeratedToEnd) {
                      end = text.length;
                    } else {
                      end = _measurePageEnd(
                        text,
                        start,
                        w,
                        h,
                        style,
                        scaler,
                      );
                      if (end >= text.length) {
                        end = text.length;
                      }
                    }
                    end = math.min(text.length, math.max(start, end));
                    final slice = text.substring(start, end);
                    return _BookReaderPage(
                      key: ValueKey<int>(i),
                      slice: slice,
                      textStyle: _bodyStyle(context),
                    );
                  },
                );
              },
            ),
          ),
          Material(
            elevation: 6,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: ValueListenableBuilder<int>(
                  valueListenable: _pageIndex,
                  builder: (context, pageIdx, _) {
                    return Row(
                      children: [
                        IconButton(
                          tooltip: "Первая страница",
                          onPressed: pageIdx > 0
                              ? () => _pageController.jumpToPage(0)
                              : null,
                          icon: const Icon(Icons.first_page),
                        ),
                        IconButton(
                          tooltip: "Назад",
                          onPressed: pageIdx > 0
                              ? () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            _enumeratedToEnd
                                ? "Стр. ${pageIdx + 1} из $pageCount"
                                : "Стр. ${pageIdx + 1}…",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        IconButton(
                          tooltip: "Вперёд",
                          onPressed: pageIdx < pageCount - 1
                              ? () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                        IconButton(
                          tooltip: "Последняя страница",
                          onPressed: () {
                            final w = _layoutMaxW;
                            final h = _layoutMaxH;
                            if (w == null || h == null || w <= 0 || h <= 0) {
                              return;
                            }
                            _extendAllPagesToEnd(text, w, h, style, scaler);
                            final last = math.max(0, _pageStarts.length - 1);
                            setState(() {});
                            _pageController.jumpToPage(last);
                            _persistOffsetNow(_pageStarts[last]);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) {
                                return;
                              }
                              _clampPageToBounds(text);
                            });
                          },
                          icon: const Icon(Icons.last_page),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookReaderPage extends StatefulWidget {
  const _BookReaderPage({
    super.key,
    required this.slice,
    required this.textStyle,
  });

  final String slice;
  final TextStyle textStyle;

  @override
  State<_BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends State<_BookReaderPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Align(
          alignment: Alignment.topLeft,
          child: SelectionArea(
            child: Text(
              widget.slice,
              style: widget.textStyle,
            ),
          ),
        ),
      ),
    );
  }
}

int endIndexForBookPage({
  required String text,
  required int start,
  required double maxWidth,
  required double maxHeight,
  required TextStyle style,
  required TextScaler textScaler,
}) {
  if (start >= text.length) {
    return text.length;
  }
  var lo = start + 1;
  var hi = text.length;
  var best = start;
  while (lo <= hi) {
    final mid = (lo + hi) ~/ 2;
    final tp = TextPainter(
      text: TextSpan(text: text.substring(start, mid), style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    if (tp.height <= maxHeight) {
      best = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  if (best <= start) {
    return math.min(text.length, start + 1);
  }
  final adjusted = adjustBookPageBreakAfterMeasure(
    text: text,
    start: start,
    end: best,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    style: style,
    textScaler: textScaler,
  );
  return adjustParagraphBlockCohesion(
    text: text,
    start: start,
    end: adjusted,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    style: style,
    textScaler: textScaler,
  );
}

/// Prefer two+ empty lines, then paragraph / sentence / word after [TextPainter] end.
///
/// The multi-blank-line rule is skipped when the laid-out height of text
/// `[start, j)` is **below half** of [maxHeight] (avoids short pages with lots
/// of trailing whitespace).
int adjustBookPageBreakAfterMeasure({
  required String text,
  required int start,
  required int end,
  required double maxWidth,
  required double maxHeight,
  required TextStyle style,
  required TextScaler textScaler,
}) {
  if (end >= text.length) {
    return end;
  }
  final lookback = math.min(4000, end - start);
  final minIndex = math.max(start + 1, end - lookback);
  final halfMinHeight =
      maxHeight > 0 ? maxHeight * 0.5 : 0.0;
  for (var j = end; j > minIndex; j--) {
    if (_isAfterTwoOrMoreEmptyLinesBoundary(text, j)) {
      if (maxHeight <= 0) {
        return j;
      }
      final filledHeight = _textPainterHeightForSubstring(
        text,
        start,
        j,
        maxWidth,
        style,
        textScaler,
      );
      if (filledHeight >= halfMinHeight) {
        return j;
      }
    }
  }
  for (var j = end; j > minIndex; j--) {
    if (_isAfterParagraphBoundary(text, j)) {
      return j;
    }
  }
  for (var j = end; j > minIndex; j--) {
    if (_isAfterSingleLineBreak(text, j)) {
      return j;
    }
  }
  for (var j = end; j > minIndex; j--) {
    if (_isAfterSentenceBoundary(text, j)) {
      return j;
    }
  }
  for (var j = end; j > minIndex; j--) {
    final ch = text[j - 1];
    if (ch == " " || ch == "\t") {
      return j;
    }
  }
  return end;
}

/// If the current break falls inside a paragraph that fits on one screen, either
/// extend the page to the end of that paragraph or move the whole paragraph to
/// the next page (whitespace tail only on the current page).
int adjustParagraphBlockCohesion({
  required String text,
  required int start,
  required int end,
  required double maxWidth,
  required double maxHeight,
  required TextStyle style,
  required TextScaler textScaler,
}) {
  if (end <= start || end > text.length) {
    return end;
  }
  if (maxHeight <= 0) {
    return end;
  }
  final anchor = _lastNonNewlineIndexOnPage(text, start, end);
  if (anchor == null) {
    return end;
  }
  final p0 = _paragraphStartBeforeOrAt(text, anchor);
  final p1 = _paragraphEndExclusive(text, p0);
  final hPara = _textPainterHeightForSubstring(
    text,
    p0,
    p1,
    maxWidth,
    style,
    textScaler,
  );
  if (hPara > maxHeight) {
    return end;
  }
  if (p0 < start) {
    final hRem =
        _textPainterHeightForSubstring(text, start, p1, maxWidth, style, textScaler);
    if (hRem <= maxHeight) {
      return p1;
    }
    return end;
  }
  final hFullPage =
      _textPainterHeightForSubstring(text, start, p1, maxWidth, style, textScaler);
  if (hFullPage <= maxHeight) {
    return p1;
  }
  if (p0 > start) {
    final hBefore =
        _textPainterHeightForSubstring(text, start, p0, maxWidth, style, textScaler);
    if (hBefore <= maxHeight) {
      return p0;
    }
  }
  return end;
}

/// Last index in `[start, end)` that is not `\n` or `\r`, or `null` if none.
int? _lastNonNewlineIndexOnPage(String text, int start, int endExclusive) {
  var i = endExclusive - 1;
  while (i >= start) {
    final ch = text[i];
    if (ch != "\n" && ch != "\r") {
      return i;
    }
    i--;
  }
  return null;
}

int _paragraphStartBeforeOrAt(String text, int charIndex) {
  if (text.isEmpty) {
    return 0;
  }
  final idx = math.min(math.max(0, charIndex), text.length - 1);
  var i = idx;
  while (i > 0) {
    if (_isAfterParagraphBoundary(text, i)) {
      return i;
    }
    i--;
  }
  return 0;
}

int _paragraphEndExclusive(String text, int paraStart) {
  var i = paraStart;
  while (i < text.length) {
    if (i + 3 < text.length && text.substring(i, i + 4) == "\r\n\r\n") {
      return i + 4;
    }
    if (i + 1 < text.length && text[i] == "\n" && text[i + 1] == "\n") {
      return i + 2;
    }
    i++;
  }
  return text.length;
}

double _textPainterHeightForSubstring(
  String text,
  int start,
  int exclusiveEnd,
  double maxWidth,
  TextStyle style,
  TextScaler textScaler,
) {
  if (exclusiveEnd <= start) {
    return 0;
  }
  final tp = TextPainter(
    text: TextSpan(text: text.substring(start, exclusiveEnd), style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);
  return tp.height;
}

/// True if [j] is immediately after a run of **three or more** newline sequences
/// (each may be `\n` or `\r\n`). That is at least **two** empty lines between
/// printed lines in a typical `.txt` (`line` + `\n` + empty + `\n` + empty + `\n` + `next`).
bool _isAfterTwoOrMoreEmptyLinesBoundary(String text, int j) {
  if (j < 3) {
    return false;
  }
  var i = j - 1;
  var consecutiveNewlines = 0;
  while (i >= 0) {
    if (text[i] == "\n") {
      consecutiveNewlines++;
      i--;
      if (i >= 0 && text[i] == "\r") {
        i--;
      }
      if (consecutiveNewlines >= 3) {
        return true;
      }
      continue;
    }
    break;
  }
  return false;
}

bool _isAfterParagraphBoundary(String text, int j) {
  if (j < 2) {
    return false;
  }
  if (text[j - 1] == "\n" && text[j - 2] == "\n") {
    return true;
  }
  if (j >= 4 && text.substring(j - 4, j) == "\r\n\r\n") {
    return true;
  }
  return false;
}

bool _isAfterSingleLineBreak(String text, int j) {
  if (j < 1 || text[j - 1] != "\n") {
    return false;
  }
  if (_isAfterParagraphBoundary(text, j)) {
    return false;
  }
  if (j >= 2 && text[j - 2] == "\r") {
    return true;
  }
  return true;
}

bool _isAfterSentenceBoundary(String text, int j) {
  if (j < 2) {
    return false;
  }
  final ws = text[j - 1];
  if (ws != " " && ws != "\t" && ws != "\n") {
    return false;
  }
  final p = text[j - 2];
  if (p == "." || p == "!" || p == "?" || p == "…" || p == "‼" || p == "⁇" || p == "⁈") {
    return true;
  }
  if (j >= 3) {
    final qOrQuote = text[j - 2];
    if (qOrQuote == "\"" ||
        qOrQuote == "\u201d" ||
        qOrQuote == "\u2019" ||
        qOrQuote == ")" ||
        qOrQuote == "\u00bb") {
      final punct = text[j - 3];
      if (punct == "." || punct == "!" || punct == "?" || punct == "…") {
        return true;
      }
    }
  }
  if (p == ";" || p == ":") {
    return true;
  }
  return false;
}
