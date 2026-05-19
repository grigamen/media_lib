part of 'app_state.dart';

/// Личные полки пользователя (только владелец).
mixin _AppStateShelves on _AppStateRefs {
  List<UserShelfSummary> _shelves = const [];
  bool _isShelvesLoading = false;
  String? _shelvesError;

  List<UserShelfSummary> get shelves => List.unmodifiable(_shelves);
  bool get isShelvesLoading => _isShelvesLoading;
  String? get shelvesError => _shelvesError;

  Future<void> fetchShelves() async {
    final session = _s._session;
    if (session == null) {
      return;
    }
    _s._isShelvesLoading = true;
    _s._shelvesError = null;
    _notifyShelvesChanged();
    try {
      _s._shelves = await _s._shelfRepository.fetchShelves(
        accessToken: session.accessToken,
      );
    } on ApiException catch (e) {
      _s._shelvesError = e.message;
    } catch (_) {
      _s._shelvesError = "Не удалось загрузить полки";
    } finally {
      _s._isShelvesLoading = false;
      _notifyShelvesChanged();
    }
  }

  void _notifyShelvesChanged() {
    scheduleMicrotask(notifyListeners);
  }

  Future<UserShelfSummary?> createShelf(String name) async {
    final session = _s._session;
    if (session == null) {
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final created = await _s._shelfRepository.createShelf(
      accessToken: session.accessToken,
      name: trimmed,
    );
    _s._shelves = [created, ..._s._shelves];
    _notifyShelvesChanged();
    return created;
  }

  Future<UserShelfDetail?> fetchShelfDetail(String shelfId) async {
    final session = _s._session;
    if (session == null) {
      return null;
    }
    return _s._shelfRepository.fetchShelf(
      accessToken: session.accessToken,
      shelfId: shelfId,
    );
  }

  Future<bool> renameShelf({
    required String shelfId,
    required String name,
  }) async {
    final session = _s._session;
    if (session == null) {
      return false;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final updated = await _s._shelfRepository.updateShelf(
      accessToken: session.accessToken,
      shelfId: shelfId,
      name: trimmed,
    );
    _s._shelves =
        _s._shelves
            .map((s) => s.id == shelfId ? updated : s)
            .toList(growable: false);
    _notifyShelvesChanged();
    return true;
  }

  Future<bool> deleteShelf(String shelfId) async {
    final session = _s._session;
    if (session == null) {
      return false;
    }
    await _s._shelfRepository.deleteShelf(
      accessToken: session.accessToken,
      shelfId: shelfId,
    );
    _s._shelves = _s._shelves.where((s) => s.id != shelfId).toList(growable: false);
    _notifyShelvesChanged();
    return true;
  }

  Future<bool> addMediaItemToShelf({
    required String shelfId,
    required String mediaItemId,
  }) async {
    final session = _s._session;
    if (session == null) {
      throw ApiException("Требуется вход в аккаунт");
    }
    final postSummary = await _s._shelfRepository.addItemToShelf(
      accessToken: session.accessToken,
      shelfId: shelfId,
      mediaItemId: mediaItemId,
    );
    final normalizedShelfId = shelfId.toLowerCase();
    final normalizedMediaId = mediaItemId.toLowerCase();

    UserShelfSummary summary = postSummary;
    var added = postSummary.itemCount > 0;

    try {
      final detail = await _s._shelfRepository.fetchShelf(
        accessToken: session.accessToken,
        shelfId: shelfId,
      );
      summary = UserShelfSummary(
        id: detail.id,
        name: detail.name,
        itemCount: detail.items.length,
        createdAt: detail.createdAt,
        updatedAt: detail.updatedAt,
      );
      added = detail.items.any(
        (item) => item.id.toLowerCase() == normalizedMediaId,
      );
    } on ApiException {
      // POST уже прошёл — считаем добавление успешным, счётчик из ответа POST.
      added = true;
    }

    final index = _s._shelves.indexWhere(
      (s) => s.id.toLowerCase() == normalizedShelfId,
    );
    if (index >= 0) {
      _s._shelves = List<UserShelfSummary>.from(_s._shelves);
      _s._shelves[index] = summary;
    } else {
      _s._shelves = [summary, ..._s._shelves];
    }
    _notifyShelvesChanged();
    return added;
  }

  Future<bool> removeMediaItemFromShelf({
    required String shelfId,
    required String mediaItemId,
  }) async {
    final session = _s._session;
    if (session == null) {
      return false;
    }
    await _s._shelfRepository.removeItemFromShelf(
      accessToken: session.accessToken,
      shelfId: shelfId,
      mediaItemId: mediaItemId,
    );
    final index = _s._shelves.indexWhere((s) => s.id == shelfId);
    if (index >= 0) {
      final old = _s._shelves[index];
      final nextCount = (old.itemCount - 1).clamp(0, 1 << 30);
      _s._shelves = List<UserShelfSummary>.from(_s._shelves);
      _s._shelves[index] = UserShelfSummary(
        id: old.id,
        name: old.name,
        itemCount: nextCount,
        createdAt: old.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    _notifyShelvesChanged();
    return true;
  }

  void _clearShelvesOnLogout() {
    _s._shelves = const [];
    _s._isShelvesLoading = false;
    _s._shelvesError = null;
  }
}
