part of 'library_screen.dart';

// Часть экрана с описанием, вкладками и кнопками: хранит список показанных форматов и открыта ли секция «файл» у владельца.

/// Общие переменные для экрана деталей: какие варианты показываем и что раскрыто у автора.
mixin _MediaItemDetailsStateFields on State<_MediaItemDetailsPage> {
  late List<MediaListItem> _variants;
  bool _isLoadingLinked = false;
  final Set<String> _ownerMainFileSectionOpen = {};
}
