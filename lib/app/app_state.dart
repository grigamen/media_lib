import "dart:async";

import "package:flutter/foundation.dart";

import "../core/config/app_config.dart";
import "../core/network/api_client.dart";
import "../features/auth/data/auth_repository.dart";
import "../features/library/data/library_repository.dart";

enum PlaybackLoadState { idle, loading, ready, error }

class PlaybackSessionConfig {
  const PlaybackSessionConfig({
    required this.mediaItemId,
    required this.mediaType,
    required this.streamUrl,
    required this.initialPositionSeconds,
    required this.initialDurationSeconds,
    required this.initialSpeed,
    required this.isDemoStream,
  });

  final String mediaItemId;
  final String mediaType;
  final String streamUrl;
  final int initialPositionSeconds;
  final int? initialDurationSeconds;
  final double initialSpeed;
  final bool isDemoStream;
}

class MediaUploadPayload {
  const MediaUploadPayload({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  final String filename;
  final String contentType;
  final Uint8List bytes;
}

class AppState extends ChangeNotifier {
  AppState()
    : _apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl),
      _isDarkMode = false {
    _authRepository = AuthRepository(_apiClient);
    _libraryRepository = LibraryRepository(_apiClient);
  }

  final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final LibraryRepository _libraryRepository;

  bool _isDarkMode;
  bool _isAuthLoading = false;
  bool _isLibraryLoading = false;
  String? _authError;
  String? _libraryError;
  AuthSession? _session;
  List<MediaListItem> _items = const [];
  bool _usingDemoItems = false;
  String _searchQuery = "";
  String? _typeFilter;
  int _selectedTab = 0;
  PlaybackLoadState _playbackLoadState = PlaybackLoadState.idle;
  String? _playbackError;
  String? _activePlaybackMediaItemId;
  bool _activePlaybackIsDemo = false;
  int _playbackPositionSeconds = 0;
  int? _playbackDurationSeconds;
  bool _playbackIsCompleted = false;
  bool _isPlaybackPlaying = false;
  bool _hasUnsyncedProgress = false;
  bool _pendingPlaybackSync = false;
  double _playbackSpeed = 1.0;
  Timer? _progressSyncTimer;

  bool get isDarkMode => _isDarkMode;
  bool get isAuthenticated => _session != null;
  bool get isAuthLoading => _isAuthLoading;
  bool get isLibraryLoading => _isLibraryLoading;
  String? get authError => _authError;
  String? get libraryError => _libraryError;
  String get userEmail => _session?.email ?? "";
  List<MediaListItem> get items => _items;
  bool get usingDemoItems => _usingDemoItems;
  String get searchQuery => _searchQuery;
  String? get typeFilter => _typeFilter;
  int get selectedTab => _selectedTab;
  PlaybackLoadState get playbackLoadState => _playbackLoadState;
  String? get playbackError => _playbackError;
  String? get activePlaybackMediaItemId => _activePlaybackMediaItemId;
  int get playbackPositionSeconds => _playbackPositionSeconds;
  int? get playbackDurationSeconds => _playbackDurationSeconds;
  bool get pendingPlaybackSync => _pendingPlaybackSync;
  double get playbackSpeed => _playbackSpeed;

  static const Duration _progressSyncInterval = Duration(seconds: 10);
  static const Map<String, String> _demoStreamByType = {
    "audiobook":
        "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    "video":
        "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
  };

  static const List<MediaListItem> _demoLibraryItems = [
    MediaListItem(
      id: "demo-hp-book",
      title: "Гарри Поттер и философский камень",
      type: "book",
      author: "Джоан Роулинг",
      description: "Первая книга цикла о Гарри Поттере.",
    ),
    MediaListItem(
      id: "demo-hp-audio",
      title: "Гарри Поттер и философский камень",
      type: "audiobook",
      author: "Джоан Роулинг",
      description: "Аудиокнижная версия первой части цикла.",
    ),
    MediaListItem(
      id: "demo-hp-video",
      title: "Гарри Поттер и философский камень",
      type: "video",
      author: "Джоан Роулинг",
      description: "Фильм-экранизация первой книги о Гарри Поттере.",
    ),
    MediaListItem(
      id: "demo-lotr-book",
      title: "Властелин колец: Братство кольца",
      type: "book",
      author: "Дж. Р. Р. Толкин",
      description: "Первая часть эпического фэнтези-цикла.",
    ),
    MediaListItem(
      id: "demo-lotr-audio",
      title: "Властелин колец: Братство кольца",
      type: "audiobook",
      author: "Дж. Р. Р. Толкин",
      description: "Аудиоверсия первой части 'Властелина колец'.",
    ),
    MediaListItem(
      id: "demo-lotr-video",
      title: "Властелин колец: Братство кольца",
      type: "video",
      author: "Дж. Р. Р. Толкин",
      description: "Киноэкранизация первой части трилогии.",
    ),
  ];

  void toggleTheme(bool enabled) {
    _isDarkMode = enabled;
    notifyListeners();
  }

  void setSelectedTab(int value) {
    _selectedTab = value;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();
    try {
      await _authRepository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      _session = await _authRepository.login(email: email, password: password);
      await fetchLibrary();
    } on ApiException catch (e) {
      _authError = e.message;
    } catch (_) {
      _authError = "Не удалось выполнить регистрацию";
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _isAuthLoading = true;
    _authError = null;
    notifyListeners();
    try {
      _session = await _authRepository.login(email: email, password: password);
      await fetchLibrary();
    } on ApiException catch (e) {
      _authError = e.message;
    } catch (_) {
      _authError = "Не удалось выполнить вход";
    } finally {
      _isAuthLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLibrary() async {
    final session = _session;
    if (session == null) {
      return;
    }
    _isLibraryLoading = true;
    _libraryError = null;
    notifyListeners();
    try {
      final fetchedItems = await _libraryRepository.fetchMediaItems(
        accessToken: session.accessToken,
        query: _searchQuery,
        type: _typeFilter,
      );
      if (fetchedItems.isEmpty) {
        _items = _buildDemoItems();
        _usingDemoItems = true;
      } else {
        _items = fetchedItems;
        _usingDemoItems = false;
      }
    } on ApiException catch (e) {
      _libraryError = e.message;
    } catch (_) {
      _libraryError = "Не удалось загрузить библиотеку";
    } finally {
      _isLibraryLoading = false;
      notifyListeners();
    }
  }

  List<MediaListItem> _buildDemoItems() {
    final query = _searchQuery.toLowerCase();
    return _demoLibraryItems
        .where((item) {
          final matchesType = _typeFilter == null || item.type == _typeFilter;
          if (!matchesType) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return item.title.toLowerCase().contains(query) ||
              (item.author ?? "").toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> applyLibraryFilters({
    required String searchQuery,
    required String? typeFilter,
  }) async {
    _searchQuery = searchQuery.trim();
    _typeFilter = typeFilter;
    await fetchLibrary();
  }

  Future<void> createMediaItem({
    required String type,
    required String title,
    String? author,
    MediaUploadPayload? uploadPayload,
  }) async {
    final session = _session;
    if (session == null) {
      return;
    }
    _libraryError = null;
    notifyListeners();
    try {
      final createdItem = await _libraryRepository.createMediaItem(
        accessToken: session.accessToken,
        type: type,
        title: title,
        author: author,
      );
      if (uploadPayload != null && (type == "audiobook" || type == "video")) {
        final initUpload = await _libraryRepository.initiateFileUpload(
          accessToken: session.accessToken,
          mediaItemId: createdItem.id,
          filename: uploadPayload.filename,
          contentType: uploadPayload.contentType,
          fileSize: uploadPayload.bytes.length,
        );
        await _libraryRepository.uploadBytesToPresignedUrl(
          uploadUrl: initUpload.uploadUrl,
          bytes: uploadPayload.bytes,
          contentType: uploadPayload.contentType,
        );
        await _libraryRepository.completeFileUpload(
          accessToken: session.accessToken,
          fileId: initUpload.fileId,
        );
        final mergedMetadata = <String, dynamic>{
          ...(createdItem.metadataJson ?? const <String, dynamic>{}),
          "media_file_id": initUpload.fileId,
        };
        await _libraryRepository.updateMediaMetadata(
          accessToken: session.accessToken,
          mediaItemId: createdItem.id,
          metadataJson: mergedMetadata,
        );
      }
      await fetchLibrary();
    } on ApiException catch (e) {
      _libraryError = e.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      _libraryError = "Не удалось добавить контент";
      notifyListeners();
      rethrow;
    }
  }

  Future<List<MediaLinkItem>> fetchLinksForItem(String mediaItemId) async {
    if (mediaItemId.startsWith("demo-")) {
      return const [];
    }
    final session = _session;
    if (session == null) {
      return const [];
    }
    return _libraryRepository.fetchMediaLinks(
      accessToken: session.accessToken,
      mediaItemId: mediaItemId,
    );
  }

  Future<MediaListItem?> fetchMediaItemById(String mediaItemId) async {
    if (mediaItemId.startsWith("demo-")) {
      for (final item in _demoLibraryItems) {
        if (item.id == mediaItemId) {
          return item;
        }
      }
      return null;
    }
    final session = _session;
    if (session == null) {
      return null;
    }
    try {
      return await _libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
      );
    } on ApiException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<PlaybackSessionConfig?> beginPlaybackSession(
    MediaListItem item,
  ) async {
    if (!_isPlayableType(item.type)) {
      _playbackLoadState = PlaybackLoadState.error;
      _playbackError = "Для этого типа контента плеер не поддерживается";
      notifyListeners();
      return null;
    }
    final currentMediaId = _activePlaybackMediaItemId;
    if (currentMediaId != null &&
        currentMediaId != item.id &&
        _hasUnsyncedProgress) {
      await flushPlaybackProgress();
    }

    _playbackLoadState = PlaybackLoadState.loading;
    _playbackError = null;
    _activePlaybackMediaItemId = item.id;
    _activePlaybackIsDemo = item.id.startsWith("demo-");
    _playbackPositionSeconds = 0;
    _playbackDurationSeconds = null;
    _playbackIsCompleted = false;
    _isPlaybackPlaying = false;
    _hasUnsyncedProgress = false;
    _pendingPlaybackSync = false;
    _stopProgressSyncTimer();
    notifyListeners();

    try {
      if (_activePlaybackIsDemo) {
        final demoUrl = _demoStreamByType[item.type];
        if (demoUrl == null) {
          throw ApiException("Не найден демо-стрим для этого типа контента");
        }
        _playbackLoadState = PlaybackLoadState.ready;
        notifyListeners();
        return PlaybackSessionConfig(
          mediaItemId: item.id,
          mediaType: item.type,
          streamUrl: demoUrl,
          initialPositionSeconds: 0,
          initialDurationSeconds: null,
          initialSpeed: _playbackSpeed,
          isDemoStream: true,
        );
      }

      final session = _session;
      if (session == null) {
        throw ApiException("Сессия авторизации не найдена");
      }

      final detailedItem = await _libraryRepository.fetchMediaItemById(
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

      final progress = await _libraryRepository.fetchMediaProgress(
        accessToken: session.accessToken,
        mediaItemId: item.id,
      );
      final streamInfo = await _libraryRepository.fetchMediaStreamUrl(
        accessToken: session.accessToken,
        fileId: mediaFileId,
      );
      _playbackPositionSeconds = progress.positionSeconds;
      _playbackDurationSeconds = progress.durationSeconds;
      _playbackIsCompleted = progress.isCompleted;
      _playbackLoadState = PlaybackLoadState.ready;
      notifyListeners();
      return PlaybackSessionConfig(
        mediaItemId: item.id,
        mediaType: item.type,
        streamUrl: streamInfo.streamUrl,
        initialPositionSeconds: progress.positionSeconds,
        initialDurationSeconds: progress.durationSeconds,
        initialSpeed: _playbackSpeed,
        isDemoStream: false,
      );
    } on ApiException catch (e) {
      _playbackLoadState = PlaybackLoadState.error;
      _playbackError = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _playbackLoadState = PlaybackLoadState.error;
      _playbackError = "Не удалось подготовить воспроизведение";
      notifyListeners();
      return null;
    }
  }

  void updatePlaybackProgress({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted = false,
  }) {
    if (_activePlaybackMediaItemId == null) {
      return;
    }

    int normalizedPosition = positionSeconds;
    int? normalizedDuration = durationSeconds;
    if (normalizedDuration != null && normalizedDuration > 0) {
      normalizedPosition = normalizedPosition.clamp(0, normalizedDuration);
    } else if (_playbackDurationSeconds != null) {
      normalizedDuration = _playbackDurationSeconds;
      normalizedPosition = normalizedPosition.clamp(
        0,
        _playbackDurationSeconds!,
      );
    }

    final hasChanged =
        normalizedPosition != _playbackPositionSeconds ||
        normalizedDuration != _playbackDurationSeconds ||
        isCompleted != _playbackIsCompleted ||
        isPlaying != _isPlaybackPlaying;

    _playbackPositionSeconds = normalizedPosition;
    _playbackDurationSeconds = normalizedDuration;
    _playbackIsCompleted =
        isCompleted ||
        (normalizedDuration != null &&
            normalizedDuration > 0 &&
            normalizedPosition >= normalizedDuration);
    _isPlaybackPlaying = isPlaying;
    _hasUnsyncedProgress = true;

    if (isPlaying) {
      _startProgressSyncTimer();
    } else {
      _stopProgressSyncTimer();
    }

    if (hasChanged) {
      notifyListeners();
    }
  }

  void setPlaybackSpeed(double value) {
    _playbackSpeed = value.clamp(0.5, 2.0);
    notifyListeners();
  }

  Future<void> pausePlaybackSession() async {
    _isPlaybackPlaying = false;
    _stopProgressSyncTimer();
    await flushPlaybackProgress();
  }

  Future<void> completePlaybackSession() async {
    _playbackIsCompleted = true;
    _hasUnsyncedProgress = true;
    _isPlaybackPlaying = false;
    _stopProgressSyncTimer();
    await flushPlaybackProgress();
  }

  Future<void> flushPlaybackProgress() async {
    await _syncActiveProgress(force: true);
  }

  void endPlaybackSession() {
    _stopProgressSyncTimer();
    _playbackLoadState = PlaybackLoadState.idle;
    _playbackError = null;
    _activePlaybackMediaItemId = null;
    _activePlaybackIsDemo = false;
    _playbackPositionSeconds = 0;
    _playbackDurationSeconds = null;
    _playbackIsCompleted = false;
    _isPlaybackPlaying = false;
    _hasUnsyncedProgress = false;
    _pendingPlaybackSync = false;
    notifyListeners();
  }

  bool _isPlayableType(String type) => type == "audiobook" || type == "video";

  void _startProgressSyncTimer() {
    if (_activePlaybackIsDemo || _activePlaybackMediaItemId == null) {
      return;
    }
    _progressSyncTimer ??= Timer.periodic(_progressSyncInterval, (_) {
      unawaited(_syncActiveProgress());
    });
  }

  void _stopProgressSyncTimer() {
    _progressSyncTimer?.cancel();
    _progressSyncTimer = null;
  }

  Future<void> _syncActiveProgress({bool force = false}) async {
    final mediaItemId = _activePlaybackMediaItemId;
    final session = _session;
    if (mediaItemId == null || session == null || _activePlaybackIsDemo) {
      return;
    }
    if (!force && !_hasUnsyncedProgress) {
      return;
    }

    try {
      final progress = await _libraryRepository.upsertMediaProgress(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
        positionSeconds: _playbackPositionSeconds,
        durationSeconds: _playbackDurationSeconds,
        isCompleted: _playbackIsCompleted,
      );
      _playbackPositionSeconds = progress.positionSeconds;
      _playbackDurationSeconds = progress.durationSeconds;
      _playbackIsCompleted = progress.isCompleted;
      _hasUnsyncedProgress = false;
      _pendingPlaybackSync = false;
      _playbackError = null;
      notifyListeners();
    } on ApiException catch (e) {
      _pendingPlaybackSync = true;
      _playbackError =
          "Не удалось синхронизировать прогресс сейчас (${e.message}). Повторим автоматически.";
      notifyListeners();
    } catch (_) {
      _pendingPlaybackSync = true;
      _playbackError = "Временная ошибка синхронизации прогресса";
      notifyListeners();
    }
  }

  void logout() {
    _stopProgressSyncTimer();
    _session = null;
    _authError = null;
    _libraryError = null;
    _items = const [];
    _usingDemoItems = false;
    _searchQuery = "";
    _typeFilter = null;
    _selectedTab = 0;
    _playbackLoadState = PlaybackLoadState.idle;
    _playbackError = null;
    _activePlaybackMediaItemId = null;
    _activePlaybackIsDemo = false;
    _playbackPositionSeconds = 0;
    _playbackDurationSeconds = null;
    _playbackIsCompleted = false;
    _isPlaybackPlaying = false;
    _hasUnsyncedProgress = false;
    _pendingPlaybackSync = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopProgressSyncTimer();
    super.dispose();
  }
}
