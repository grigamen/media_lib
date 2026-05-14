part of "book_reader_screen.dart";

/// Индекс конца отрезка `[start, …)`, который помещается в окно: бинарный поиск + сдвиг к «удобным» границам.
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

/// Сдвигает конец страницы назад к двойным пустым строкам, абзацу, переводу строки, концу предложения или пробелу.
///
/// Правило «две пустые строки» отключается, если текст до кандидата занимает меньше половины высоты — иначе страницы становятся короткими из-за хвоста пробелов.
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

/// Если разрыв попал внутрь абзаца, который целиком помещается на экране — расширить страницу до конца абзаца или перенести весь абзац на следующую.
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
