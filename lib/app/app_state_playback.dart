part of 'app_state.dart';

/// Воспроизведение: подготовка сессии (демо/стрим), прогресс, синхронизация с сервером и S3 presigned.
mixin _AppStatePlayback on _AppStateRefs {
  /// Собирает [PlaybackSessionConfig] для плеера: прогресс (сервер vs локально), файл стрима, presigned URL.
  Future<PlaybackSessionOutcome> beginPlaybackSession(
    MediaListItem item,
  ) async {
    if (!_isPlayableType(item.type)) {
      const message = "Для этого типа контента плеер не поддерживается";
      _s._playbackLoadState = PlaybackLoadState.error;
      _s._playbackError = message;
      notifyListeners();
      return PlaybackSessionOutcome.failure(message);
    }
    final currentMediaId = _s._activePlaybackMediaItemId;
    if (currentMediaId != null &&
        currentMediaId != item.id &&
        _s._hasUnsyncedProgress) {
      await flushPlaybackProgress();
    }

    _s._playbackLoadState = PlaybackLoadState.loading;
    _s._playbackError = null;
    _s._activePlaybackMediaItemId = item.id;
    _s._activePlaybackIsDemo = item.id.startsWith("demo-");
    _s._playbackPositionSeconds = 0;
    _s._playbackDurationSeconds = null;
    _s._playbackIsCompleted = false;
    _s._isPlaybackPlaying = false;
    _s._hasUnsyncedProgress = false;
    _s._pendingPlaybackSync = false;
    _stopProgressSyncTimer();
    notifyListeners();

    try {
      if (_s._activePlaybackIsDemo) {
        final demoUrl = DemoLibraryData.streamByType[item.type];
        if (demoUrl == null) {
          throw ApiException("Не найден демо-стрим для этого типа контента");
        }
        _s._playbackLoadState = PlaybackLoadState.ready;
        notifyListeners();
        await _s.recordMediaItemView(item.id);
        return PlaybackSessionOutcome.success(
          PlaybackSessionConfig(
            mediaItemId: item.id,
            mediaType: item.type,
            streamUrl: demoUrl,
            initialPositionSeconds: 0,
            initialDurationSeconds: null,
            initialSpeed: _s._playbackSpeed,
            isDemoStream: true,
            streamOptions: const [],
            activeStreamFileId: null,
          ),
        );
      }

      final session = _s._session;
      if (session == null) {
        throw ApiException("Сессия авторизации не найдена");
      }

      final detailedItem = await _s._libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: item.id,
      );
      final mediaFileId = item.mediaFileId ?? detailedItem.mediaFileId;
      if (mediaFileId == null || mediaFileId.isEmpty) {
        throw ApiException(
          "Для этого контента не указан media_file_id в metadata_json. "
          "Добавьте файл и сохраните его идентификатор в metadata.",
        );
      }

      final fetchedServer = await _s._libraryRepository.fetchMediaProgress(
        accessToken: session.accessToken,
        mediaItemId: item.id,
      );
      await _s._ensureLocalPersistence();
      final uid = _s._currentUserId;
      ProgressMirrorRow? mirror;
      if (uid != null && _s._progressStore != null) {
        mirror = await _s._progressStore!.loadMirror(
          userId: uid,
          mediaItemId: item.id,
        );
      }
      final lww = PlaybackProgressResolution.resolve(
        serverPositionSeconds: fetchedServer.positionSeconds,
        serverDurationSeconds: fetchedServer.durationSeconds,
        serverIsCompleted: fetchedServer.isCompleted,
        serverUpdatedAtUtcMs: fetchedServer.updatedAtUtcMs,
        local: mirror,
      );

      late final MediaProgress progress;
      if (!lww.needsPushToServer) {
        progress = fetchedServer;
        if (uid != null && _s._progressStore != null) {
          await _s._progressStore!.upsertMirror(
            userId: uid,
            mediaItemId: item.id,
            positionSeconds: progress.positionSeconds,
            durationSeconds: progress.durationSeconds,
            isCompleted: progress.isCompleted,
            pendingSync: false,
          );
        }
      } else {
        try {
          progress = await _s._libraryRepository.upsertMediaProgress(
            accessToken: session.accessToken,
            mediaItemId: item.id,
            positionSeconds: lww.positionSeconds,
            durationSeconds: lww.durationSeconds,
            isCompleted: lww.isCompleted,
          );
          if (uid != null && _s._progressStore != null) {
            await _s._progressStore!.upsertMirror(
              userId: uid,
              mediaItemId: item.id,
              positionSeconds: progress.positionSeconds,
              durationSeconds: progress.durationSeconds,
              isCompleted: progress.isCompleted,
              pendingSync: false,
            );
          }
        } catch (_) {
          progress = MediaProgress.synthesized(
            mediaItemId: item.id,
            positionSeconds: lww.positionSeconds,
            durationSeconds: lww.durationSeconds,
            isCompleted: lww.isCompleted,
          );
          if (uid != null && _s._progressStore != null) {
            await _s._progressStore!.upsertMirror(
              userId: uid,
              mediaItemId: item.id,
              positionSeconds: lww.positionSeconds,
              durationSeconds: lww.durationSeconds,
              isCompleted: lww.isCompleted,
              pendingSync: true,
            );
          }
        }
      }

      final allFiles = await _s._libraryRepository.fetchMediaFilesForItem(
        accessToken: session.accessToken,
        mediaItemId: item.id,
      );
      final readyFiles =
          allFiles.where((f) => f.uploadStatus == "ready").toList();
      readyFiles.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final streamCandidates = playbackStreamCandidates(readyFiles, item.type);
      final filesToPickFrom =
          streamCandidates.isNotEmpty ? streamCandidates : readyFiles;
      final streamOptions =
          streamCandidates.length > 1
              ? playbackStreamOptionsFromFiles(streamCandidates)
              : const <PlaybackStreamOption>[];

      final String streamFileId;
      final String? activeStreamFileId;
      if (filesToPickFrom.isNotEmpty) {
        final picked = pickPlaybackFileIdFromReady(filesToPickFrom, mediaFileId);
        streamFileId = picked ?? filesToPickFrom.first.id;
        activeStreamFileId = streamFileId;
      } else {
        streamFileId = mediaFileId;
        activeStreamFileId = null;
      }

      final streamInfo = await _s._libraryRepository.fetchMediaStreamUrl(
        accessToken: session.accessToken,
        fileId: streamFileId,
      );
      _s._playbackPositionSeconds = progress.positionSeconds;
      _s._playbackDurationSeconds = progress.durationSeconds;
      _s._playbackIsCompleted = progress.isCompleted;
      _s._playbackLoadState = PlaybackLoadState.ready;
      notifyListeners();
      await _s.recordMediaItemView(item.id);
      return PlaybackSessionOutcome.success(
        PlaybackSessionConfig(
          mediaItemId: item.id,
          mediaType: item.type,
          streamUrl: streamInfo.streamUrl,
          initialPositionSeconds: progress.positionSeconds,
          initialDurationSeconds: progress.durationSeconds,
          initialSpeed: _s._playbackSpeed,
          isDemoStream: false,
          streamOptions: streamOptions,
          activeStreamFileId: activeStreamFileId,
        ),
      );
    } on ApiException catch (e) {
      _s._playbackLoadState = PlaybackLoadState.error;
      _s._playbackError = e.message;
      notifyListeners();
      return PlaybackSessionOutcome.failure(e.message);
    } catch (_) {
      const fallback = "Не удалось подготовить воспроизведение";
      _s._playbackLoadState = PlaybackLoadState.error;
      _s._playbackError = fallback;
      notifyListeners();
      return PlaybackSessionOutcome.failure(fallback);
    }
  }

  /// Presigned URL для уже известного [fileId] (смена формата/повторная инициализация плеера).
  Future<String?> fetchPlaybackStreamUrl(String fileId) async {
    final session = _s._session;
    if (session == null) {
      return null;
    }
    try {
      final streamInfo = await _s._libraryRepository.fetchMediaStreamUrl(
        accessToken: session.accessToken,
        fileId: fileId,
      );
      return streamInfo.streamUrl;
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Текст книги для читалки (демо, кэш, загрузка по сети через [BookContentLoader]).
  Future<String> loadBookContent(MediaListItem item) {
    return _s._bookContentLoader.loadPlainTextForReading(
      item: item,
      session: _s._session,
    );
  }

  /// Обновляет позицию/длительность из плеера; при воспроизведении запускает дебаунс-синк на сервер.
  void updatePlaybackProgress({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted = false,
  }) {
    if (_s._activePlaybackMediaItemId == null) {
      return;
    }

    int normalizedPosition = positionSeconds;
    int? normalizedDuration = durationSeconds;
    if (normalizedDuration != null && normalizedDuration > 0) {
      normalizedPosition = normalizedPosition.clamp(0, normalizedDuration);
    } else if (_s._playbackDurationSeconds != null) {
      normalizedDuration = _s._playbackDurationSeconds;
      normalizedPosition = normalizedPosition.clamp(
        0,
        _s._playbackDurationSeconds!,
      );
    }

    final hasChanged =
        normalizedPosition != _s._playbackPositionSeconds ||
        normalizedDuration != _s._playbackDurationSeconds ||
        isCompleted != _s._playbackIsCompleted ||
        isPlaying != _s._isPlaybackPlaying;

    _s._playbackPositionSeconds = normalizedPosition;
    _s._playbackDurationSeconds = normalizedDuration;
    _s._playbackIsCompleted =
        isCompleted ||
        (normalizedDuration != null &&
            normalizedDuration > 0 &&
            normalizedPosition >= normalizedDuration);
    _s._isPlaybackPlaying = isPlaying;
    _s._hasUnsyncedProgress = true;

    if (isPlaying) {
      _startProgressSyncTimer();
    } else {
      _stopProgressSyncTimer();
    }

    if (hasChanged) {
      notifyListeners();
    }
  }

  /// Глобальная скорость воспроизведения (ограничение 0.5–2.0).
  void setPlaybackSpeed(double value) {
    _s._playbackSpeed = value.clamp(0.5, 2.0);
    notifyListeners();
  }

  /// Пауза: останавливает таймер синка и сразу пушит прогресс.
  Future<void> pausePlaybackSession() async {
    _s._isPlaybackPlaying = false;
    _stopProgressSyncTimer();
    await flushPlaybackProgress();
  }

  /// Конец просмотра/прослушивания: помечает завершённым и отправляет финальный прогресс.
  Future<void> completePlaybackSession() async {
    _s._playbackIsCompleted = true;
    _s._hasUnsyncedProgress = true;
    _s._isPlaybackPlaying = false;
    _stopProgressSyncTimer();
    await flushPlaybackProgress();
  }

  /// Немедленная отправка текущего прогресса активного трека на сервер (и зеркало в БД).
  Future<void> flushPlaybackProgress() async {
    await _syncActiveProgress(force: true);
  }

  /// Сбрасывает состояние плеера в UI (закрытие панели) без сохранения новой позиции здесь.
  void endPlaybackSession() {
    _stopProgressSyncTimer();
    _s._playbackLoadState = PlaybackLoadState.idle;
    _s._playbackError = null;
    _s._activePlaybackMediaItemId = null;
    _s._activePlaybackIsDemo = false;
    _s._playbackPositionSeconds = 0;
    _s._playbackDurationSeconds = null;
    _s._playbackIsCompleted = false;
    _s._isPlaybackPlaying = false;
    _s._hasUnsyncedProgress = false;
    _s._pendingPlaybackSync = false;
    notifyListeners();
  }

  /// Закрывает оверлей прогресса presigned-загрузки после завершения операции.
  void dismissPresignedUploadOverlay() {
    _s._uploadTracker.dismiss();
  }

  /// Типы, для которых есть потоковое воспроизведение в приложении.
  bool _isPlayableType(String type) => type == "audiobook" || type == "video";

  /// Полный цикл presigned: основной медиафайл → metadata `media_file_id`.
  Future<void> _attachUploadIfNeeded({
    required AuthSession session,
    required MediaListItem item,
    required String type,
    required MediaUploadPayload? uploadPayload,
  }) async {
    if (uploadPayload == null) {
      return;
    }
    final contentType = MediaUploadPayload.resolvedMainFileContentType(
      filename: uploadPayload.filename,
      declaredContentType: uploadPayload.contentType,
      mediaItemType: type,
    );
    final initUpload = await _s._libraryRepository.initiateFileUpload(
      accessToken: session.accessToken,
      mediaItemId: item.id,
      filename: uploadPayload.filename,
      contentType: contentType,
      fileSize: uploadPayload.byteLength,
    );
    try {
      _s._uploadTracker.begin();
      if (uploadPayload.bytes != null) {
        await _s._libraryRepository.uploadBytesToPresignedUrl(
          uploadUrl: initUpload.uploadUrl,
          bytes: uploadPayload.bytes!,
          contentType: contentType,
          onProgress: _s._uploadTracker.reportProgress,
        );
      } else {
        await _s._libraryRepository.uploadFileToPresignedUrl(
          uploadUrl: initUpload.uploadUrl,
          filePath: uploadPayload.filePath!,
          contentLength: uploadPayload.byteLength,
          contentType: contentType,
          onProgress: _s._uploadTracker.reportProgress,
        );
      }
      await _s._libraryRepository.completeFileUpload(
        accessToken: session.accessToken,
        fileId: initUpload.fileId,
      );
      final mergedMetadata = <String, dynamic>{
        ...(item.metadataJson ?? const <String, dynamic>{}),
        "media_file_id": initUpload.fileId,
      };
      await _s._libraryRepository.updateMediaMetadata(
        accessToken: session.accessToken,
        mediaItemId: item.id,
        metadataJson: mergedMetadata,
      );
    } finally {
      _s._uploadTracker.end();
    }
  }

  /// Загрузка обложки через presigned и обновление `cover_url` / `cover_file_id` у произведения.
  Future<void> _attachCoverUploadIfNeeded({
    required AuthSession session,
    required MediaListItem item,
    required MediaUploadPayload? coverUploadPayload,
  }) async {
    if (coverUploadPayload == null) {
      return;
    }
    final contentType = MediaUploadPayload.resolvedCoverContentType(
      filename: coverUploadPayload.filename,
      declaredContentType: coverUploadPayload.contentType,
    );
    final initUpload = await _s._libraryRepository.initiateFileUpload(
      accessToken: session.accessToken,
      mediaItemId: item.id,
      filename: coverUploadPayload.filename,
      contentType: contentType,
      fileSize: coverUploadPayload.byteLength,
    );
    try {
      _s._uploadTracker.begin();
      if (coverUploadPayload.bytes != null) {
        await _s._libraryRepository.uploadBytesToPresignedUrl(
          uploadUrl: initUpload.uploadUrl,
          bytes: coverUploadPayload.bytes!,
          contentType: contentType,
          onProgress: _s._uploadTracker.reportProgress,
        );
      } else {
        await _s._libraryRepository.uploadFileToPresignedUrl(
          uploadUrl: initUpload.uploadUrl,
          filePath: coverUploadPayload.filePath!,
          contentLength: coverUploadPayload.byteLength,
          contentType: contentType,
          onProgress: _s._uploadTracker.reportProgress,
        );
      }
      await _s._libraryRepository.completeFileUpload(
        accessToken: session.accessToken,
        fileId: initUpload.fileId,
      );
      final stream = await _s._libraryRepository.fetchMediaStreamUrl(
        accessToken: session.accessToken,
        fileId: initUpload.fileId,
      );
      final freshItem = await _s._libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: item.id,
      );
      final mergedMetadata = <String, dynamic>{
        ...(freshItem.metadataJson ?? const <String, dynamic>{}),
        "cover_file_id": initUpload.fileId,
      };
      await _s._libraryRepository.updateMediaItem(
        accessToken: session.accessToken,
        mediaItemId: item.id,
        coverUrl: stream.streamUrl,
        metadataJson: mergedMetadata,
      );
    } finally {
      _s._uploadTracker.end();
    }
  }

  /// Периодический пуш прогресса во время воспроизведения (не для демо).
  void _startProgressSyncTimer() {
    if (_s._activePlaybackIsDemo || _s._activePlaybackMediaItemId == null) {
      return;
    }
    _s._playbackSyncTimer.start(() => _syncActiveProgress());
  }

  /// Останавливает таймер фоновой синхронизации прогресса.
  void _stopProgressSyncTimer() {
    _s._playbackSyncTimer.stop();
  }

  /// Отправляет локальный прогресс на API или сохраняет «зеркало» при офлайне / ошибке.
  Future<void> _syncActiveProgress({bool force = false}) async {
    final mediaItemId = _s._activePlaybackMediaItemId;
    final session = _s._session;
    if (mediaItemId == null || session == null || _s._activePlaybackIsDemo) {
      return;
    }
    if (!force && !_s._hasUnsyncedProgress) {
      return;
    }

    await _s._ensureLocalPersistence();

    await _s._playbackPusher.pushOrMirrorPending(
      session: session,
      mediaItemId: mediaItemId,
      userId: _s._currentUserId,
      progressStore: _s._progressStore,
      positionSeconds: _s._playbackPositionSeconds,
      durationSeconds: _s._playbackDurationSeconds,
      isCompleted: _s._playbackIsCompleted,
      force: force,
      hasUnsyncedProgress: _s._hasUnsyncedProgress,
      onServerAccepted: (progress) {
        _s._playbackPositionSeconds = progress.positionSeconds;
        _s._playbackDurationSeconds = progress.durationSeconds;
        _s._playbackIsCompleted = progress.isCompleted;
        _s._hasUnsyncedProgress = false;
        _s._pendingPlaybackSync = false;
        _s._playbackError = null;
        notifyListeners();
      },
      onTransientFailure: (msg) {
        _s._pendingPlaybackSync = true;
        _s._playbackError = msg;
        notifyListeners();
      },
    );
  }
}
