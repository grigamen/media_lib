import "dart:async";
import "dart:math" as math;

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../data/library_repository.dart";

part "book_reader_fields.dart";
part "book_reader_measure.dart";
part "book_reader_pagination.dart";
part "book_reader_page_widget.dart";

/// Полноэкранная читалка: [TextPainter] только для границ страниц и префетча, не на весь текст.
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

/// Состояние читалки: пагинация вынесена в [_BookReaderPagination], поля — в [_BookReaderFields].
class _BookReaderScreenState extends State<BookReaderScreen>
    with _BookReaderFields, _BookReaderPagination {
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
    _paginationBump.dispose();
    _pageController.dispose();
    super.dispose();
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
                      _initialReaderLayoutPending = false;
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: "Выйти из чтения",
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.item.title),
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

                final layoutReady = text.isEmpty ||
                    (_layoutSignature != null && _layoutMaxW != null);

                if (text.isNotEmpty && !layoutReady) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedBuilder(
                      animation:
                          Listenable.merge([_pageIndex, _paginationBump]),
                      builder: (context, _) {
                        final pageCount = _itemCountForPageView(text);
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
                            scheduleMicrotask(() {
                              if (!mounted) {
                                return;
                              }
                              final lenBefore = _pageStarts.length;
                              final enumBefore = _enumeratedToEnd;
                              if (w > 0 && h > 0) {
                                _ensurePageMeasurable(
                                  text,
                                  i + 1,
                                  w,
                                  h,
                                  style,
                                  scaler,
                                );
                                _prepareNeighbors(
                                  text,
                                  w,
                                  h,
                                  style,
                                  scaler,
                                  i,
                                );
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
                                _notifyPaginationChanged();
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
                                final len0 = _pageStarts.length;
                                final enum0 = _enumeratedToEnd;
                                _ensurePageMeasurable(
                                  text,
                                  i,
                                  w,
                                  h,
                                  style,
                                  scaler,
                                );
                                if (!mounted) {
                                  return;
                                }
                                if (len0 != _pageStarts.length ||
                                    enum0 != _enumeratedToEnd) {
                                  _notifyPaginationChanged();
                                }
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) {
                                  return;
                                }
                                final len0 = _pageStarts.length;
                                final enum0 = _enumeratedToEnd;
                                _ensurePageMeasurable(
                                  text,
                                  i,
                                  w,
                                  h,
                                  style,
                                  scaler,
                                );
                                if (!mounted) {
                                  return;
                                }
                                if (len0 != _pageStarts.length ||
                                    enum0 != _enumeratedToEnd) {
                                  _notifyPaginationChanged();
                                }
                              });
                              return const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
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
                    if (text.isNotEmpty && _initialReaderLayoutPending)
                      ColoredBox(
                        color: theme.scaffoldBackgroundColor,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
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
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pageIndex, _paginationBump]),
                  builder: (context, _) {
                    final pageIdx = _pageIndex.value;
                    final pageCount = _itemCountForPageView(text);
                    return Row(
                      children: [
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
                                : "Стр. ${pageIdx + 1}",
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

