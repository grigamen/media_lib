part of "book_reader_screen.dart";

/// Ленивая пагинация книги: SharedPreferences, разбиение на страницы по размеру текста и [PageView].
mixin _BookReaderPagination on _BookReaderFields {
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
        _initialReaderLayoutPending = true;
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

  void _notifyPaginationChanged() {
    _paginationBump.value = _paginationBump.value + 1;
  }

  TextStyle _bodyStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    return base.copyWith(height: 1.35);
  }

  /// Buckets text scale so [sig] does not flip every frame on float noise (which would
  /// reset pagination). Theme font size is part of [sig] separately.
  String _layoutScaleBucket(TextScaler scaler) {
    const ref = 100.0;
    return (scaler.scale(ref) * 100 / ref).round().toString();
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
          _initialReaderLayoutPending = false;
        });
      });
      return;
    }

    final scaler = MediaQuery.textScalerOf(context);
    final style = _bodyStyle(context);
    final sig =
        "${text.length}_${maxW.round()}_${maxH.round()}_fs${(style.fontSize ?? 14).round()}_sc${_layoutScaleBucket(scaler)}";

    // Only [sig] (rounded sizes + text length + scale) must match. Comparing raw
    // [maxW]/[maxH] with == is wrong: constraints jitter by sub-pixel values every
    // frame, which used to re-enter layout sync, reset [_pageStarts] to [0], and
    // break pagination (e.g. stuck after two pages).
    if (sig == _layoutSignature && _pageStarts.isNotEmpty) {
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
        _initialReaderLayoutPending = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        final idx = await _pageIndexForCharOffset(
          text,
          maxW,
          maxH,
          style,
          scaler,
          anchor,
        );
        if (!mounted) {
          return;
        }
        _prepareNeighbors(text, maxW, maxH, style, scaler, idx);
        _pageIndex.value = idx;
        // Rebuild [PageView] with real [itemCount] before [jumpToPage], otherwise
        // [jumpToPage] runs while [itemCount] is still small, clamps to page 1 and
        // [onPageChanged] overwrites [_pageIndex] — footer shows "Стр. 2" until manual flip.
        _notifyPaginationChanged();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          if (_pageController.hasClients) {
            final maxIdx = math.max(0, _itemCountForPageView(text) - 1);
            final j = idx.clamp(0, maxIdx);
            _pageIndex.value = j;
            _pageController.jumpToPage(j);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            _clampPageToBounds(text);
            setState(() {
              _initialReaderLayoutPending = false;
            });
          });
        });
      });
    });
  }

  /// Walk forward with [TextPainter] until [offset] lies on page p; return p.
  ///
  /// Yields the event loop every few page measures so [CircularProgressIndicator]
  /// can tick while seeking in long books.
  Future<int> _pageIndexForCharOffset(
    String text,
    double maxW,
    double maxH,
    TextStyle style,
    TextScaler scaler,
    int offset,
  ) async {
    if (text.isEmpty) {
      return 0;
    }
    var o = offset.clamp(0, math.max(0, text.length - 1));
    _pageStarts = <int>[0];
    _enumeratedToEnd = false;
    var page = 0;
    var loops = 0;
    while (true) {
      if (loops > 0 && loops % 2 == 0) {
        await Future<void>.delayed(Duration.zero);
        if (!mounted) {
          return 0;
        }
      }
      loops++;
      if (page >= _pageStarts.length) {
        if (_pageStarts.isEmpty) {
          return 0;
        }
        final last = _pageStarts.last;
        if (last >= text.length) {
          _enumeratedToEnd = true;
          return math.max(0, _pageStarts.length - 1);
        }
        final next = _measurePageEnd(text, last, maxW, maxH, style, scaler);
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
      final endExcl = _measurePageEnd(text, start, maxW, maxH, style, scaler);
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
}
