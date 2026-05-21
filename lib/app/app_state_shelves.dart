part of 'app_state.dart';

/// Личные полки пользователя (только владелец).
mixin _AppStateShelves on _AppStateRefs {
  List<UserShelfSummary> _shelves = const [];
  bool _isShelvesLoading = false;
  String? _shelvesError;

  List<UserShelfSummary> get shelves => List.unmodifiable(_shelves);

  /// Полки для главной: сначала недавно открытые, затем по дате обновления.
  List<UserShelfSummary> get homeShelves {
    final list = List<UserShelfSummary>.from(_shelves);
    list.sort((a, b) {
      final aMs = _s._shelfLastOpenedAtMs[a.id] ?? 0;
      final bMs = _s._shelfLastOpenedAtMs[b.id] ?? 0;
      if (aMs != bMs) {
        return bMs.compareTo(aMs);
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  bool get isShelvesLoading => _isShelvesLoading;
  String? get shelvesError => _shelvesError;

  void markShelfOpened(String shelfId) {
    final id = shelfId.trim();
    if (id.isEmpty) {
      return;
    }
    _s._shelfLastOpenedAtMs[id] = DateTime.now().toUtc().millisecondsSinceEpoch;
    _notifyShelvesChanged();
  }

  Future<void> fetchShelves() async {
    final session = _s._session;
    if (session == null) {
      return;
    }
    _s._isShelvesLoading = true;
    _s._shelvesError = null;
    _notifyShelvesChanged();
    try {
      final fetched = await _s._shelfRepository.fetchShelves(
        accessToken: session.accessToken,
      );
      _s._shelves = await _resolveShelfCovers(fetched, session);
    } on ApiException catch (e) {
      _s._shelvesError = e.message;
    } catch (_) {
      _s._shelvesError = "Не удалось загрузить полки";
    } finally {
      _s._isShelvesLoading = false;
      _notifyShelvesChanged();
    }
  }

  /// После обновления каталога — подтянуть presigned-обложки полок.
  Future<void> refreshShelfCoversAfterCatalog() async {
    final session = _s._session;
    if (session == null || _s._shelves.isEmpty) {
      return;
    }
    _s._shelves = await _resolveShelfCovers(_s._shelves, session);
    _notifyShelvesChanged();
  }

  Future<List<UserShelfSummary>> _resolveShelfCovers(
    List<UserShelfSummary> shelves,
    AuthSession session,
  ) async {
    final byId = <String, MediaListItem>{
      for (final item in _s._items) item.id: item,
    };
    final resolved = <UserShelfSummary>[];
    for (final shelf in shelves) {
      resolved.add(await _resolveShelfCover(shelf, session, byId));
    }
    return resolved;
  }

  Future<UserShelfSummary> _resolveShelfCover(
    UserShelfSummary shelf,
    AuthSession session,
    Map<String, MediaListItem> catalogById,
  ) async {
    var mediaId = shelf.coverMediaItemId?.trim();
    MediaListItem? item =
        mediaId != null && mediaId.isNotEmpty
            ? _catalogItemById(catalogById.values, mediaId)
            : null;

    if (item == null && shelf.itemCount > 0) {
      try {
        final detail = await _s._shelfRepository.fetchShelf(
          accessToken: session.accessToken,
          shelfId: shelf.id,
        );
        item = pickShelfCoverItem(detail.items);
        mediaId = item?.id;
      } on ApiException {
        return shelf;
      } catch (_) {
        return shelf;
      }
    }

    if (item == null) {
      return shelf;
    }

    final refreshed = await _s._coverRefresh.withFreshCoverUrl(
      session: session,
      item: item,
    );
    final url = refreshed.coverUrl?.trim();
    if (url == null || url.isEmpty) {
      return shelf.copyWith(coverMediaItemId: item.id);
    }
    return shelf.copyWith(coverUrl: url, coverMediaItemId: item.id);
  }

  MediaListItem? _catalogItemById(
    Iterable<MediaListItem> items,
    String itemId,
  ) {
    final normalized = itemId.toLowerCase();
    for (final item in items) {
      if (item.id == itemId || item.id.toLowerCase() == normalized) {
        return item;
      }
    }
    return null;
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
    final detail = await _s._shelfRepository.fetchShelf(
      accessToken: session.accessToken,
      shelfId: shelfId,
    );
    if (detail.items.isEmpty) {
      return detail;
    }
    final refreshedItems = await _s._coverRefresh.withFreshCoverUrls(
      session: session,
      items: detail.items,
    );
    return UserShelfDetail(
      id: detail.id,
      name: detail.name,
      items: refreshedItems,
      createdAt: detail.createdAt,
      updatedAt: detail.updatedAt,
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
    _s._shelves = _s._shelves
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
    _s._shelves = _s._shelves
        .where((s) => s.id != shelfId)
        .toList(growable: false);
    _s._shelfLastOpenedAtMs.remove(shelfId);
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
      final coverItem = pickShelfCoverItem(detail.items);
      summary = UserShelfSummary(
        id: detail.id,
        name: detail.name,
        itemCount: detail.items.length,
        coverUrl: postSummary.coverUrl,
        coverMediaItemId: postSummary.coverMediaItemId ?? coverItem?.id,
        createdAt: detail.createdAt,
        updatedAt: detail.updatedAt,
      );
      summary = await _resolveShelfCover(summary, session, {
        for (final i in _s._items) i.id: i,
      });
      added = detail.items.any(
        (item) => item.id.toLowerCase() == normalizedMediaId,
      );
    } on ApiException {
      added = true;
      summary = await _resolveShelfCover(postSummary, session, {
        for (final i in _s._items) i.id: i,
      });
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
      var updated = old.copyWith(
        itemCount: nextCount,
        updatedAt: DateTime.now().toUtc(),
      );
      if (nextCount > 0) {
        updated = await _resolveShelfCover(updated, session, {
          for (final i in _s._items) i.id: i,
        });
      } else {
        updated = UserShelfSummary(
          id: old.id,
          name: old.name,
          itemCount: 0,
          createdAt: old.createdAt,
          updatedAt: DateTime.now().toUtc(),
        );
      }
      _s._shelves = List<UserShelfSummary>.from(_s._shelves);
      _s._shelves[index] = updated;
    }
    _notifyShelvesChanged();
    return true;
  }

  void _clearShelvesOnLogout() {
    _s._shelves = const [];
    _s._isShelvesLoading = false;
    _s._shelvesError = null;
    _s._shelfLastOpenedAtMs.clear();
  }
}
