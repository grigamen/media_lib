import "dart:math" as math;

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../data/library_repository.dart";

/// Full-screen reader with pagination and saved character offset.
///
/// Pagination uses a fast length estimate (no per-book [TextPainter] pass),
/// so large texts do not block the UI thread.
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

  List<int> _pageStarts = const [];
  int _currentPage = 0;

  /// Layout + text length signature for which [_pageStarts] was computed.
  String? _layoutSignature;

  int _savedCharOffset = 0;

  /// Avoids queueing duplicate post-frame splits for the same layout signature.
  String? _splitScheduledForSig;

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
        _pageStarts = const [];
        _splitScheduledForSig = null;
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

  Future<void> _persistOffset(int charStart) async {
    _savedCharOffset = charStart;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_offsetKey, charStart);
  }

  TextStyle _bodyStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return base.copyWith(height: 1.35);
  }

  int _anchorCharOffset() {
    if (_pageStarts.isNotEmpty && _currentPage < _pageStarts.length) {
      return _pageStarts[_currentPage];
    }
    return _savedCharOffset;
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  void _recomputePagesIfNeeded(
    BuildContext context,
    String text,
    double maxW,
    double maxH,
  ) {
    if (maxW <= 0 || maxH <= 0) {
      return;
    }

    if (text.isEmpty) {
      const single = <int>[0];
      if (_listEquals(_pageStarts, single) && _layoutSignature == "empty") {
        return;
      }
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
          _pageStarts = single;
          _currentPage = 0;
          _layoutSignature = "empty";
        });
      });
      return;
    }

    final scaler = MediaQuery.textScalerOf(context);
    final style = _bodyStyle(context);
    final charsPerPage = estimateCharsPerPage(
      maxWidth: maxW,
      maxHeight: maxH,
      style: style,
      textScaler: scaler,
    );
    final sig =
        "${text.length}_${maxW.round()}_${maxH.round()}_${scaler.hashCode}_$charsPerPage";

    if (sig == _layoutSignature && _pageStarts.isNotEmpty) {
      return;
    }
    if (_splitScheduledForSig == sig) {
      return;
    }
    _splitScheduledForSig = sig;

    final starts = computeFastPageStarts(text, charsPerPage);
    final anchor = _anchorCharOffset();
    final idx = pageIndexForCharOffset(starts, text.length, anchor);
    final nextPage = math.max(0, math.min(idx, math.max(0, starts.length - 1)));
    final oldStarts = _pageStarts;
    final needsJump = !_listEquals(oldStarts, starts) || oldStarts.isEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _splitScheduledForSig = null;
      if (!mounted) {
        return;
      }
      setState(() {
        _pageStarts = starts;
        _layoutSignature = sig;
        _currentPage = nextPage;
      });
      if (needsJump) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) {
            return;
          }
          final safe = math.max(
            0,
            math.min(nextPage, math.max(0, starts.length - 1)),
          );
          if ((_pageController.page?.round() ?? 0) != safe) {
            _pageController.jumpToPage(safe);
          }
        });
      }
    });
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
                      _pageStarts = const [];
                      _splitScheduledForSig = null;
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
    final pageCount = math.max(1, _pageStarts.isEmpty ? 1 : _pageStarts.length);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: "Выйти из чтения",
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.item.title),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                "${_currentPage + 1} / $pageCount",
                style: theme.textTheme.titleMedium,
              ),
            ),
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

                // Sync pagination: fast path keeps the UI thread responsive.
                _recomputePagesIfNeeded(context, text, maxW, maxH);

                if (text.isNotEmpty && _pageStarts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                return PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    if (i < _pageStarts.length) {
                      _persistOffset(_pageStarts[i]);
                    }
                  },
                  itemBuilder: (context, i) {
                    if (_pageStarts.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final start = _pageStarts[i];
                    final end = i + 1 < _pageStarts.length
                        ? _pageStarts[i + 1]
                        : text.length;
                    final slice = text.substring(start, end);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SelectableText(
                          slice,
                          style: _bodyStyle(context),
                        ),
                      ),
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
                child: Row(
                  children: [
                    IconButton(
                      tooltip: "Первая страница",
                      onPressed: _currentPage > 0
                          ? () => _pageController.jumpToPage(0)
                          : null,
                      icon: const Icon(Icons.first_page),
                    ),
                    IconButton(
                      tooltip: "Назад",
                      onPressed: _currentPage > 0
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
                        "Стр. ${_currentPage + 1} из $pageCount",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: "Вперёд",
                      onPressed: _currentPage < pageCount - 1
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
                      onPressed: _currentPage < pageCount - 1
                          ? () => _pageController.jumpToPage(pageCount - 1)
                          : null,
                      icon: const Icon(Icons.last_page),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int pageIndexForCharOffset(List<int> starts, int textLen, int offset) {
  if (starts.isEmpty) {
    return 0;
  }
  final o = offset.clamp(0, math.max(0, textLen - 1));
  for (var i = 0; i < starts.length; i++) {
    final pageEnd = i + 1 < starts.length ? starts[i + 1] : textLen;
    if (o >= starts[i] && o < pageEnd) {
      return i;
    }
  }
  return starts.length - 1;
}

/// Rough capacity for one «screen» of plain text from layout metrics.
int estimateCharsPerPage({
  required double maxWidth,
  required double maxHeight,
  required TextStyle style,
  required TextScaler textScaler,
}) {
  final fontSize = style.fontSize ?? 16.0;
  final lineHeightFactor = style.height ?? 1.35;
  final scaledFont = textScaler.scale(fontSize);
  final lineHeight = scaledFont * lineHeightFactor;
  final lines = math.max(1, (maxHeight / lineHeight).floor());
  final approxCharWidth = scaledFont * 0.52;
  final columns = math.max(8, (maxWidth / approxCharWidth).floor());
  final n = lines * columns;
  return n.clamp(1200, 10000);
}

/// O(number of pages) breaks; avoids [TextPainter] over the whole book.
List<int> computeFastPageStarts(String text, int charsPerPage) {
  if (text.isEmpty) {
    return const [0];
  }
  final target = math.max(400, charsPerPage);
  final preferLookback = math.min(
    12000,
    math.max(target * 2, 2200),
  );
  final starts = <int>[0];
  var i = 0;
  while (i < text.length) {
    var end = math.min(i + target, text.length);
    if (end < text.length) {
      var snapped = snapPageBreakBackward(
        text,
        i,
        end,
        maxLookback: preferLookback,
      );
      if (snapped <= i &&
          preferLookback < end - i - 1) {
        snapped = snapPageBreakBackward(
          text,
          i,
          end,
          maxLookback: end - i - 1,
        );
      }
      if (snapped <= i) {
        snapped = end;
      }
      end = snapped;
    }
    if (end <= i) {
      end = math.min(i + 1, text.length);
    }
    if (end >= text.length) {
      break;
    }
    starts.add(end);
    i = end;
  }
  return starts;
}

/// Picks an exclusive end index ≤ [tentativeEnd], preferring paragraph and sentence edges.
int snapPageBreakBackward(
  String text,
  int pageStart,
  int tentativeEnd, {
  required int maxLookback,
}) {
  if (tentativeEnd >= text.length) {
    return tentativeEnd;
  }

  final span = tentativeEnd - pageStart - 1;
  final lookback = math.min(maxLookback, math.max(0, span));
  if (lookback == 0) {
    return tentativeEnd;
  }

  final minIndex = math.max(pageStart + 1, tentativeEnd - lookback);

  for (var j = tentativeEnd; j > minIndex; j--) {
    if (_isAfterParagraphBoundary(text, j)) {
      return j;
    }
  }
  for (var j = tentativeEnd; j > minIndex; j--) {
    if (_isAfterSingleLineBreak(text, j)) {
      return j;
    }
  }
  for (var j = tentativeEnd; j > minIndex; j--) {
    if (_isAfterSentenceBoundary(text, j)) {
      return j;
    }
  }
  for (var j = tentativeEnd; j > minIndex; j--) {
    final ch = text[j - 1];
    if (ch == " " || ch == "\t") {
      return j;
    }
  }
  return tentativeEnd;
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
