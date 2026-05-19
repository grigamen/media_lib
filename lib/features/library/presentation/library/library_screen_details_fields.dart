part of 'library_screen.dart';

// Часть экрана с описанием, вкладками и кнопками: хранит список показанных форматов и открыта ли секция «файл» у владельца.

/// Общие переменные для экрана деталей: какие варианты показываем и что раскрыто у автора.
mixin _MediaItemDetailsStateFields on State<_MediaItemDetailsPage> {
  late List<MediaListItem> _variants;
  late TabController _tabController;
  String? _focusedMediaItemId;
  bool _isLoadingLinked = false;
  final Set<String> _ownerMainFileSectionOpen = {};

  int _variantIndexForFocused() {
    if (_variants.isEmpty) {
      return 0;
    }
    final focusedId = _focusedMediaItemId;
    if (focusedId != null) {
      final index = _variants.indexWhere((item) => item.id == focusedId);
      if (index >= 0) {
        return index;
      }
    }
    return 0;
  }

  void _onTabIndexChanged() {
    if (_tabController.indexIsChanging || _variants.isEmpty) {
      return;
    }
    final index = _tabController.index.clamp(0, _variants.length - 1);
    _focusedMediaItemId = _variants[index].id;
  }

  void _syncTabControllerToFocusedVariant() {
    if (_variants.isEmpty) {
      return;
    }
    final length = _variants.length;
    final index = _variantIndexForFocused().clamp(0, length - 1);
    if (_tabController.length != length) {
      final oldController = _tabController;
      oldController.removeListener(_onTabIndexChanged);
      _tabController = TabController(
        length: length,
        vsync: this as TickerProvider,
        initialIndex: index,
      );
      _tabController.addListener(_onTabIndexChanged);
      oldController.dispose();
    } else if (_tabController.index != index) {
      _tabController.index = index;
    }
  }
}
