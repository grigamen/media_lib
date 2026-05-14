part of "book_reader_screen.dart";

mixin _BookReaderFields on State<BookReaderScreen> {
  static const _prefsNs = "book_reader_v1";

  late final PageController _pageController;

  String? _text;
  Object? _loadError;
  bool _loading = true;

  /// Start index of page i. Page i ends at starts[i+1] or EOF.
  /// Built lazily: always starts as [0].
  List<int> _pageStarts = <int>[0];

  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(0);

  /// Bumped when [_pageStarts] / [_enumeratedToEnd] change so only the reader
  /// subtree rebuilds — avoids rebuilding the whole [Scaffold] on each flip.
  final ValueNotifier<int> _paginationBump = ValueNotifier<int>(0);

  Timer? _persistTimer;

  /// True once we know the last page begins at [_pageStarts.last] and ends at EOF.
  bool _enumeratedToEnd = false;

  String? _layoutSignature;

  int _savedCharOffset = 0;

  String? _splitScheduledForSig;

  double? _layoutMaxW;
  double? _layoutMaxH;

  /// True until first [PageView] layout + [jumpToPage] for saved offset finishes.
  bool _initialReaderLayoutPending = false;

  /// [TextPainter] boundary cache: layout + start offset → exclusive end.
  final Map<String, int> _pageMeasureCache = <String, int>{};

  String get _offsetKey => "${_prefsNs}_off_${widget.item.id}";
  String get _fileKey => "${_prefsNs}_file_${widget.item.id}";
}
