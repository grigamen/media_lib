part of 'app_state.dart';

/// Логика каталога медиа в [AppState]: загрузка списка, фильтры, демо/кэш,
/// админские списки, CRUD произведений, presigned-загрузки и привязка файлов.
mixin _AppStateLibrary on _AppStateRefs {
  /// Загружает список произведений с API; при пустом ответе может подставить демо или кэш.
  Future<void> fetchLibrary() async {
    final session = _s._session;
    if (session == null) {
      return;
    }
    _s._isLibraryLoading = true;
    _s._libraryError = null;
    notifyListeners();
    final userId = _s._currentUserId;
    await _s._ensureLocalPersistence();
    final cacheKey =
        userId != null
            ? CatalogCacheStore.buildCacheKey(
              userId: userId,
              searchQuery: _s._searchQuery,
              selectedTypes: _s._selectedTypes,
              selectedGenres: _s._selectedGenres,
            )
            : null;
    try {
      final fetchedItems = dedupeMediaItemsById(
        await _s._libraryRepository.fetchMediaItems(
          accessToken: session.accessToken,
          query: _s._searchQuery,
          types: _s._selectedTypes,
          genres: _s._selectedGenres,
        ),
      );
      if (fetchedItems.isEmpty) {
        if (_s._allowDemoFallback && !_s._sawNonEmptyServerLibrary) {
          _s._items = DemoLibraryData.filteredDemoItems(
            searchQuery: _s._searchQuery,
            selectedTypes: _s._selectedTypes,
            selectedGenres: _s._selectedGenres,
          );
          _s._usingDemoItems = true;
        } else {
          _s._items = const [];
          _s._usingDemoItems = false;
        }
      } else {
        _s._sawNonEmptyServerLibrary = true;
        _s._items = await _s._coverRefresh.withFreshCoverUrls(
          session: session,
          items: fetchedItems,
        );
        _s._usingDemoItems = false;
      }
      if (userId != null &&
          cacheKey != null &&
          _s._catalogCache != null &&
          !_s._usingDemoItems) {
        await _s._catalogCache!.replaceCatalog(
          userId: userId,
          cacheKey: cacheKey,
          items: _s._items,
        );
      }
      await _s._flushPendingProgressIfOnline();
      try {
        final fetchedGenres = await _s._libraryRepository.fetchAvailableGenres(
          accessToken: session.accessToken,
        );
        if (fetchedGenres.isNotEmpty) {
          _s._availableGenres = normalizeLibraryGenres(fetchedGenres);
        }
      } catch (_) {
        // Список произведений уже загружен; сбой жанров не должен блокировать библиотеку.
      }
    } on ApiException catch (e) {
      _s._libraryError = e.message;
      if (userId != null && cacheKey != null && _s._catalogCache != null) {
        final resolved = await _s._catalogCache!.loadCatalogWithFallback(
          userId: userId,
          exactCacheKey: cacheKey,
        );
        final cached = resolved.items;
        if (cached != null) {
          _s._items = cached;
          _s._usingDemoItems = false;
          if (resolved.fallback == CatalogCacheFallback.baseSnapshot) {
            _s._libraryError =
                "Нет связи с сервером. Показан сохранённый каталог без текущих фильтров "
                "(${e.message}).";
          } else {
            _s._libraryError =
                "Нет связи с сервером. Показан сохранённый каталог (${e.message}).";
          }
        }
      }
    } catch (_) {
      _s._libraryError = "Не удалось загрузить библиотеку";
      if (userId != null && cacheKey != null && _s._catalogCache != null) {
        final resolved = await _s._catalogCache!.loadCatalogWithFallback(
          userId: userId,
          exactCacheKey: cacheKey,
        );
        final cached = resolved.items;
        if (cached != null) {
          _s._items = cached;
          _s._usingDemoItems = false;
          if (resolved.fallback == CatalogCacheFallback.baseSnapshot) {
            _s._libraryError =
                "Нет связи с сервером. Показан сохранённый каталог без текущих фильтров.";
          } else {
            _s._libraryError =
                "Нет связи с сервером. Показан сохранённый каталог.";
          }
        }
      }
    } finally {
      _s._isLibraryLoading = false;
      await refreshOwnedWorksCount();
      notifyListeners();
      unawaited(_prefetchLibraryUserRatings());
    }
  }

  /// Подгружает оценки для карточек сетки библиотеки (параллельно, небольшими пачками).
  Future<void> _prefetchLibraryUserRatings() async {
    if (_s._session == null) {
      return;
    }
    final ids =
        _s._items
            .map((item) => item.id)
            .where((id) => id.isNotEmpty && !id.startsWith("demo-"))
            .toSet()
            .toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    const batchSize = 8;
    var changed = false;
    for (var offset = 0; offset < ids.length; offset += batchSize) {
      final batch = ids.skip(offset).take(batchSize);
      await Future.wait(
        batch.map((id) async {
          if (_s._userRatingCacheByMediaId.containsKey(id)) {
            return;
          }
          try {
            await fetchMediaProgressForItem(id);
            changed = true;
          } catch (_) {
            _s._userRatingCacheByMediaId[id] = null;
            changed = true;
          }
        }),
      );
      if (changed) {
        notifyListeners();
        changed = false;
      }
    }
  }

  /// Обновляет [hasOwnedWorks] / [ownedWorksTotal] (limit=1, сервер отдаёт total).
  Future<void> refreshOwnedWorksCount() async {
    final session = _s._session;
    if (session == null) {
      _s._ownedWorksTotal = 0;
      return;
    }
    try {
      final r = await _s._libraryRepository.fetchMediaItemsWithMeta(
        accessToken: session.accessToken,
        mine: true,
        limit: 1,
        offset: 0,
      );
      _s._ownedWorksTotal = r.total;
    } catch (_) {
      // не сбрасываем счётчик при временной ошибке сети
    }
  }

  /// Полный список «мои произведения» для отдельного экрана (до 100 записей).
  Future<List<MediaListItem>> fetchMyMediaItemsForPanel() async {
    final session = _s._session;
    if (session == null) {
      return const [];
    }
    final r = await _s._libraryRepository.fetchMediaItemsWithMeta(
      accessToken: session.accessToken,
      mine: true,
      limit: 100,
      offset: 0,
    );
    final list = dedupeMediaItemsById(r.items);
    return _s._coverRefresh.withFreshCoverUrls(session: session, items: list);
  }

  /// Первые страницы для админ-панели: «на модерации» и общий каталог (с пагинацией «ещё»).
  Future<void> fetchAdminCatalog({bool showLoadingIndicator = true}) async {
    final session = _s._session;
    if (session == null || !_s._isAdminUser) {
      return;
    }
    await _s._adminCatalog.fetchCatalog(
      session: session,
      isAdminUser: _s._isAdminUser,
      showLoadingIndicator: showLoadingIndicator,
    );
  }

  /// Подгрузка следующей страницы списка «на модерации».
  Future<void> loadMoreAdminPendingCatalog() async {
    final session = _s._session;
    if (session == null) {
      return;
    }
    await _s._adminCatalog.loadMorePending(
      session: session,
      isAdminUser: _s._isAdminUser,
    );
  }

  /// Подгрузка следующей страницы общего списка (вкладка «Удаление»).
  Future<void> loadMoreAdminAllCatalog() async {
    final session = _s._session;
    if (session == null) {
      return;
    }
    await _s._adminCatalog.loadMoreAll(
      session: session,
      isAdminUser: _s._isAdminUser,
    );
  }

  /// Применяет поиск/типы/жанры и перезагружает каталог.
  Future<void> applyLibraryFilters({
    required String searchQuery,
    List<String> selectedTypes = const [],
    List<String> selectedGenres = const [],
  }) async {
    _s._searchQuery = searchQuery.trim();
    _s._selectedTypes = normalizeLibrarySelectedTypes(selectedTypes);
    _s._selectedGenres = normalizeLibraryGenres(selectedGenres);
    await fetchLibrary();
  }

  /// Сортировка сетки библиотеки (клиентская, без перезапроса каталога).
  void setLibrarySort(LibrarySortField field, {bool? descending}) {
    final direction = descending ?? field.defaultDescending;
    if (_s._librarySortField == field &&
        _s._librarySortDescending == direction) {
      return;
    }
    _s._librarySortField = field;
    _s._librarySortDescending = direction;
    notifyListeners();
  }

  void toggleLibrarySortDirection() {
    _s._librarySortDescending = !_s._librarySortDescending;
    notifyListeners();
  }

  /// Последовательно удаляет все собственные произведения пользователя (для «сброса аккаунта»).
  Future<void> deleteAllMediaItems() async {
    final session = _s._session;
    if (session == null) {
      return;
    }
    _s._isLibraryLoading = true;
    _s._libraryError = null;
    notifyListeners();
    try {
      while (true) {
        final page = await _s._libraryRepository.fetchMediaItems(
          accessToken: session.accessToken,
          query: null,
          type: null,
        );
        if (page.isEmpty) {
          break;
        }
        final ownItems = page
            .where(
              (item) => item.userId != null && item.userId == _s._currentUserId,
            )
            .toList(growable: false);
        if (ownItems.isEmpty) {
          break;
        }
        for (final item in ownItems) {
          await _s._libraryRepository.deleteMediaItem(
            accessToken: session.accessToken,
            mediaItemId: item.id,
          );
        }
      }
      _s._allowDemoFallback = false;
      _s._items = const [];
      _s._adminCatalog.reset();
      _s._usingDemoItems = false;
      final uid = _s._currentUserId;
      if (uid != null) {
        await _s._ensureLocalPersistence();
        await _s._catalogCache?.clearForUser(uid);
      }
    } on ApiException catch (e) {
      _s._libraryError = e.message;
    } catch (_) {
      _s._libraryError = "Не удалось удалить произведения";
    } finally {
      _s._isLibraryLoading = false;
      await refreshOwnedWorksCount();
      notifyListeners();
    }
  }

  /// Возвращает `true`, если сервер принял удаление (204).
  Future<bool> deleteMediaItemAsAdmin(String mediaItemId) async {
    final session = _s._session;
    if (session == null || !_s._isAdminUser) {
      return false;
    }
    _s._libraryError = null;
    _s._adminCatalog.state.error = null;
    notifyListeners();
    try {
      await _s._libraryRepository.deleteMediaItem(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
      );
      _s._items = _s._items.where((e) => e.id != mediaItemId).toList(growable: false);
      _s._adminCatalog.removeItemFromEverywhere(mediaItemId);
      notifyListeners();
      await Future.wait<void>([
        fetchLibrary(),
        fetchAdminCatalog(showLoadingIndicator: false),
      ]);
      return true;
    } on ApiException catch (e) {
      _s._libraryError = e.message;
      _s._adminCatalog.state.error = e.message;
      return false;
    } catch (_) {
      _s._libraryError = "Не удалось удалить произведение";
      _s._adminCatalog.state.error = "Не удалось удалить произведение";
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Создаёт новое произведение и при необходимости прикрепляет обложку и основной файл (presigned).
  Future<MediaListItem?> createMediaItem({
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
  }) async {
    final session = _s._session;
    if (session == null) {
      return null;
    }
    _s._libraryError = null;
    notifyListeners();
    try {
      final createdItem = await _s._libraryRepository.createMediaItem(
        accessToken: session.accessToken,
        type: type,
        title: title,
        author: author,
        coverUrl: coverUrl,
        genres: genres,
      );
      await _s._attachUploadIfNeeded(
        session: session,
        item: createdItem,
        type: type,
        uploadPayload: uploadPayload,
      );
      await _s._attachCoverUploadIfNeeded(
        session: session,
        item: createdItem,
        coverUploadPayload: coverUploadPayload,
      );
      await fetchLibrary();
      for (final e in _s._items) {
        if (e.id == createdItem.id) {
          return e;
        }
      }
      return createdItem;
    } on ApiException catch (e) {
      _s._libraryError = e.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      _s._libraryError = "Не удалось добавить контент";
      notifyListeners();
      rethrow;
    }
  }

  /// Админ: подтвердить (`approve == true`) или отклонить произведение.
  Future<bool> moderateMediaItemAsAdmin({
    required String mediaItemId,
    required bool approve,
  }) async {
    final session = _s._session;
    if (session == null || !_s._isAdminUser) {
      return false;
    }
    _s._adminCatalog.state.error = null;
    notifyListeners();
    try {
      if (approve) {
        await _s._libraryRepository.approveMediaModeration(
          accessToken: session.accessToken,
          mediaItemId: mediaItemId,
        );
      } else {
        await _s._libraryRepository.rejectMediaModeration(
          accessToken: session.accessToken,
          mediaItemId: mediaItemId,
        );
      }
      await Future.wait([
        fetchLibrary(),
        fetchAdminCatalog(showLoadingIndicator: false),
      ]);
      return true;
    } on ApiException catch (e) {
      _s._adminCatalog.state.error = e.message;
      return false;
    } catch (_) {
      _s._adminCatalog.state.error = "Не удалось изменить статус модерации";
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Обновляет метаданные варианта и заменяет файлы через presigned при передаче payload.
  Future<MediaListItem> updateMediaItem({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  }) async {
    final session = _s._session;
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }
    _s._libraryError = null;
    notifyListeners();
    try {
      final updated = await _s._libraryRepository.updateMediaItem(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
        title: title,
        author: author,
        coverUrl: coverUrl,
        genres: genres,
        description: description,
      );
      await _s._attachCoverUploadIfNeeded(
        session: session,
        item: updated,
        coverUploadPayload: coverUploadPayload,
      );
      await _s._attachUploadIfNeeded(
        session: session,
        item: updated,
        type: type,
        uploadPayload: uploadPayload,
      );
      final freshUpdatedItem = await _s._libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
      );
      final resolvedUpdatedItem = await _s._coverRefresh.withFreshCoverUrl(
        session: session,
        item: freshUpdatedItem,
      );
      await fetchLibrary();
      return resolvedUpdatedItem;
    } on ApiException catch (e) {
      _s._libraryError = e.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      _s._libraryError = "Не удалось обновить произведение";
      notifyListeners();
      rethrow;
    }
  }

  /// Добавляет новый формат (новое [MediaListItem]) и связывает его с исходным произведением ссылкой.
  Future<MediaListItem> addFormatToWork({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  }) async {
    final session = _s._session;
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }
    _s._libraryError = null;
    notifyListeners();
    try {
      final createdItem = await _s._libraryRepository.createMediaItem(
        accessToken: session.accessToken,
        type: type,
        title: title,
        author: author,
        coverUrl: coverUrl,
        genres: genres,
      );
      if (description != null && description.trim().isNotEmpty) {
        await _s._libraryRepository.updateMediaItem(
          accessToken: session.accessToken,
          mediaItemId: createdItem.id,
          description: description,
        );
      }
      await _s._attachUploadIfNeeded(
        session: session,
        item: createdItem,
        type: type,
        uploadPayload: uploadPayload,
      );
      await _s._attachCoverUploadIfNeeded(
        session: session,
        item: createdItem,
        coverUploadPayload: coverUploadPayload,
      );
      await _s._libraryRepository.createMediaLink(
        accessToken: session.accessToken,
        sourceMediaId: sourceMediaItemId,
        targetMediaId: createdItem.id,
        relationType: "related",
      );
      await fetchLibrary();
      final fresh = await _s._libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: createdItem.id,
      );
      return fresh;
    } on ApiException catch (e) {
      _s._libraryError = e.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      _s._libraryError = "Не удалось добавить новый формат произведения";
      notifyListeners();
      rethrow;
    }
  }

  /// Список файлов в хранилище, привязанных к произведению (для владельца/карточки).
  Future<List<MediaFileSummary>> fetchMediaFilesForItem(
    String mediaItemId,
  ) async {
    if (mediaItemId.startsWith("demo-")) {
      return const [];
    }
    final session = _s._session;
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }
    return _s._libraryRepository.fetchMediaFilesForItem(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
    );
  }

  /// Проставляет в метаданных произведения `media_file_id` как основной файл для плеера.
  Future<void> bindMainMediaFileToItem({
    required String mediaItemId,
    required String fileId,
  }) async {
    if (mediaItemId.startsWith("demo-")) {
      return;
    }
    final session = _s._session;
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }
    final item = await _s._libraryRepository.fetchMediaItemById(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
    );
    final mergedMetadata = <String, dynamic>{
      ...(item.metadataJson ?? const <String, dynamic>{}),
      "media_file_id": fileId,
    };
    await _s._libraryRepository.updateMediaMetadata(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
      metadataJson: mergedMetadata,
    );
    await fetchLibrary();
    notifyListeners();
  }

  /// Загружает выбранный пользователем файл в storage и привязывает его к произведению.
  Future<void> uploadAndBindMainMediaFile({
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  }) async {
    if (mediaItemId.startsWith("demo-")) {
      return;
    }
    final session = _s._session;
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }
    final item = await _s._libraryRepository.fetchMediaItemById(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
    );
    await _s._attachUploadIfNeeded(
      session: session,
      item: item,
      type: item.type,
      uploadPayload: uploadPayload,
    );
    await fetchLibrary();
    notifyListeners();
  }

  /// Связи между произведениями (форматы одной работы и т.п.).
  Future<List<MediaLinkItem>> fetchLinksForItem(String mediaItemId) async {
    if (mediaItemId.startsWith("demo-")) {
      return const [];
    }
    final session = _s._session;
    if (session == null) {
      return const [];
    }
    return _s._libraryRepository.fetchMediaLinks(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
    );
  }

  /// Одно произведение по id с освежением URL обложки; для демо — из локальных данных.
  Future<MediaListItem?> fetchMediaItemById(String mediaItemId) async {
    if (mediaItemId.startsWith("demo-")) {
      final item = DemoLibraryData.findItemById(mediaItemId);
      if (item == null) {
        return null;
      }
      return item.copyWith(
        viewsCount: _s._demoViewsCountByMediaId[mediaItemId] ?? 0,
      );
    }
    final session = _s._session;
    if (session == null) {
      return null;
    }
    try {
      final item = await _s._libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
      );
      return await _s._coverRefresh.withFreshCoverUrl(session: session, item: item);
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Прогресс и оценка по произведению (`GET …/progress` создаёт строку при отсутствии).
  Future<MediaProgress> fetchMediaProgressForItem(String mediaItemId) async {
    if (mediaItemId.startsWith("demo-")) {
      return MediaProgress.synthesized(
        mediaItemId: mediaItemId,
        positionSeconds: 0,
        durationSeconds: null,
        isCompleted: false,
        ratingStars: _s._demoUserRatingsByMediaId[mediaItemId],
      );
    }
    final session = _s._session;
    if (session == null) {
      throw ApiException("Войдите в аккаунт, чтобы оценивать произведения.");
    }
    final progress = await _s._libraryRepository.fetchMediaProgress(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
    );
    _s._userRatingCacheByMediaId[mediaItemId] = progress.ratingStars;
    return progress;
  }

  /// Сохранить оценку 1–5 для текущего пользователя.
  Future<MediaProgress> setMediaItemUserRating({
    required String mediaItemId,
    required int stars,
  }) async {
    if (mediaItemId.startsWith("demo-")) {
      final clamped = stars.clamp(1, 5);
      _s._demoUserRatingsByMediaId[mediaItemId] = clamped;
      _s._userRatingCacheByMediaId[mediaItemId] = clamped;
      return MediaProgress.synthesized(
        mediaItemId: mediaItemId,
        positionSeconds: 0,
        durationSeconds: null,
        isCompleted: false,
        ratingStars: clamped,
      );
    }
    final session = _s._session;
    if (session == null) {
      throw ApiException("Войдите в аккаунт, чтобы оценивать произведения.");
    }
    final progress = await _s._libraryRepository.setMediaItemRating(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
      stars: stars.clamp(1, 5),
    );
    _s._userRatingCacheByMediaId[mediaItemId] = progress.ratingStars;
    return progress;
  }

  /// Убрать личную оценку (звёзды).
  Future<MediaProgress> clearMediaItemUserRating(String mediaItemId) async {
    if (mediaItemId.startsWith("demo-")) {
      _s._demoUserRatingsByMediaId.remove(mediaItemId);
      _s._userRatingCacheByMediaId[mediaItemId] = null;
      return MediaProgress.synthesized(
        mediaItemId: mediaItemId,
        positionSeconds: 0,
        durationSeconds: null,
        isCompleted: false,
      );
    }
    final session = _s._session;
    if (session == null) {
      throw ApiException("Войдите в аккаунт, чтобы оценивать произведения.");
    }
    final progress = await _s._libraryRepository.clearMediaItemRating(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
    );
    _s._userRatingCacheByMediaId[mediaItemId] = null;
    return progress;
  }

  /// Оценка всей «работы»: читаем первую найденную среди форматов, при сохранении пишем во все.
  Future<int?> fetchWorkUserRatingStars(List<String> mediaItemIds) async {
    int? found;
    for (final id in mediaItemIds) {
      if (id.trim().isEmpty) {
        continue;
      }
      if (_s._userRatingCacheByMediaId.containsKey(id)) {
        final cached = _s._userRatingCacheByMediaId[id];
        if (cached != null) {
          return cached;
        }
        found ??= cached;
        continue;
      }
      try {
        final progress = await fetchMediaProgressForItem(id);
        if (progress.ratingStars != null) {
          return progress.ratingStars;
        }
        found ??= progress.ratingStars;
      } catch (_) {
        // Пропускаем недоступный вариант, остальные форматы всё равно проверим.
      }
    }
    return found;
  }

  Future<int?> setWorkUserRatingStars({
    required List<String> mediaItemIds,
    required int stars,
  }) async {
    final clamped = stars.clamp(1, 5);
    int? result;
    for (final id in mediaItemIds) {
      if (id.trim().isEmpty) {
        continue;
      }
      if (id.startsWith("demo-")) {
        _s._demoUserRatingsByMediaId[id] = clamped;
        _s._userRatingCacheByMediaId[id] = clamped;
        result = clamped;
        continue;
      }
      final progress = await setMediaItemUserRating(
        mediaItemId: id,
        stars: clamped,
      );
      result = progress.ratingStars;
    }
    notifyListeners();
    unawaited(fetchLibrary());
    return result;
  }

  /// Увеличивает счётчик просмотров формата (плеер или «Читать») и обновляет каталог в памяти.
  Future<void> recordMediaItemView(String mediaItemId) async {
    final normalizedId = mediaItemId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    if (normalizedId.startsWith("demo-")) {
      final next = (_s._demoViewsCountByMediaId[normalizedId] ?? 0) + 1;
      _s._demoViewsCountByMediaId[normalizedId] = next;
      _s._patchItemViewsCountInCatalog(normalizedId, next);
      notifyListeners();
      return;
    }
    final session = _s._session;
    if (session == null) {
      return;
    }
    try {
      final updated = await _s._libraryRepository.recordMediaItemView(
        accessToken: session.accessToken,
        mediaItemId: normalizedId,
      );
      _s._patchItemViewsCountInCatalog(normalizedId, updated.viewsCount);
      notifyListeners();
    } catch (_) {
      // Сбой счётчика не блокирует воспроизведение.
    }
  }

  void _patchItemViewsCountInCatalog(String mediaItemId, int viewsCount) {
    _s._items = _s._items
        .map(
          (item) =>
              item.id == mediaItemId
                  ? item.copyWith(viewsCount: viewsCount)
                  : item,
        )
        .toList(growable: false);
  }

  Future<void> clearWorkUserRatingStars(List<String> mediaItemIds) async {
    for (final id in mediaItemIds) {
      if (id.trim().isEmpty) {
        continue;
      }
      await clearMediaItemUserRating(id);
    }
    notifyListeners();
    unawaited(fetchLibrary());
  }
}
