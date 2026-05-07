import "dart:async";
import "dart:convert";

import "package:archive/archive.dart";
import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

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
  List<String> _availableGenres = const [
    "Фэнтези",
    "Фантастика",
    "Детектив",
    "Классика",
    "Роман",
    "Нон-фикшн",
  ];
  bool _usingDemoItems = false;
  bool _allowDemoFallback = true;
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
  Map<String, List<String>> _recentlyViewedItemIdsByUser = const {};
  String? _currentUserId;

  bool get isDarkMode => _isDarkMode;
  bool get isAuthenticated => _session != null;
  bool get isAuthLoading => _isAuthLoading;
  bool get isLibraryLoading => _isLibraryLoading;
  String? get authError => _authError;
  String? get libraryError => _libraryError;
  String get userEmail => _session?.email ?? "";
  List<MediaListItem> get items => _items;
  List<String> get availableGenres => _availableGenres;
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
  String? get currentUserId => _currentUserId;
  List<MediaListItem> get recentlyViewedItems {
    final userId = _currentUserId;
    if (userId == null || _items.isEmpty) {
      return const [];
    }
    final recentIds = _recentlyViewedItemIdsByUser[userId] ?? const <String>[];
    if (recentIds.isEmpty) {
      return const [];
    }
    final byId = <String, MediaListItem>{for (final item in _items) item.id: item};
    return recentIds
        .map((id) => byId[id])
        .whereType<MediaListItem>()
        .toList(growable: false);
  }

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
      genres: ["Фэнтези"],
      description: "Первая книга цикла о Гарри Поттере.",
    ),
    MediaListItem(
      id: "demo-hp-audio",
      title: "Гарри Поттер и философский камень",
      type: "audiobook",
      author: "Джоан Роулинг",
      genres: ["Фэнтези"],
      description: "Аудиокнижная версия первой части цикла.",
    ),
    MediaListItem(
      id: "demo-hp-video",
      title: "Гарри Поттер и философский камень",
      type: "video",
      author: "Джоан Роулинг",
      genres: ["Фэнтези"],
      description: "Фильм-экранизация первой книги о Гарри Поттере.",
    ),
    MediaListItem(
      id: "demo-lotr-book",
      title: "Властелин колец: Братство кольца",
      type: "book",
      author: "Дж. Р. Р. Толкин",
      genres: ["Фэнтези"],
      description: "Первая часть эпического фэнтези-цикла.",
    ),
    MediaListItem(
      id: "demo-lotr-audio",
      title: "Властелин колец: Братство кольца",
      type: "audiobook",
      author: "Дж. Р. Р. Толкин",
      genres: ["Фэнтези"],
      description: "Аудиоверсия первой части 'Властелина колец'.",
    ),
    MediaListItem(
      id: "demo-lotr-video",
      title: "Властелин колец: Братство кольца",
      type: "video",
      author: "Дж. Р. Р. Толкин",
      genres: ["Фэнтези"],
      description: "Киноэкранизация первой части трилогии.",
    ),
  ];

  void toggleTheme(bool enabled) {
    _isDarkMode = enabled;
    notifyListeners();
  }

  void setSelectedTab(int value) {
    _selectedTab = value.clamp(0, 4);
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
      _currentUserId = _extractUserIdFromAccessToken(_session!.accessToken);
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
      _currentUserId = _extractUserIdFromAccessToken(_session!.accessToken);
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
        if (_allowDemoFallback) {
          _items = _buildDemoItems();
          _usingDemoItems = true;
        } else {
          _items = const [];
          _usingDemoItems = false;
        }
      } else {
        _items = await _withFreshCoverUrls(
          session: session,
          items: fetchedItems,
        );
        _usingDemoItems = false;
      }
      final fetchedGenres = await _libraryRepository.fetchAvailableGenres(
        accessToken: session.accessToken,
      );
      if (fetchedGenres.isNotEmpty) {
        _availableGenres = _normalizeGenres(fetchedGenres);
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

  Future<void> deleteAllMediaItems() async {
    final session = _session;
    if (session == null) {
      return;
    }
    _isLibraryLoading = true;
    _libraryError = null;
    notifyListeners();
    try {
      while (true) {
        final page = await _libraryRepository.fetchMediaItems(
          accessToken: session.accessToken,
          query: null,
          type: null,
        );
        if (page.isEmpty) {
          break;
        }
        final ownItems = page
            .where((item) => item.userId != null && item.userId == _currentUserId)
            .toList(growable: false);
        if (ownItems.isEmpty) {
          break;
        }
        for (final item in ownItems) {
          await _libraryRepository.deleteMediaItem(
            accessToken: session.accessToken,
            mediaItemId: item.id,
          );
        }
      }
      _allowDemoFallback = false;
      _items = const [];
      _usingDemoItems = false;
    } on ApiException catch (e) {
      _libraryError = e.message;
    } catch (_) {
      _libraryError = "Не удалось удалить произведения";
    } finally {
      _isLibraryLoading = false;
      notifyListeners();
    }
  }

  Future<void> createMediaItem({
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
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
        coverUrl: coverUrl,
        genres: genres,
      );
      await _attachUploadIfNeeded(
        session: session,
        item: createdItem,
        type: type,
        uploadPayload: uploadPayload,
      );
      await _attachCoverUploadIfNeeded(
        session: session,
        item: createdItem,
        coverUploadPayload: coverUploadPayload,
      );
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
    final session = _session;
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }
    _libraryError = null;
    notifyListeners();
    try {
      final updated = await _libraryRepository.updateMediaItem(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
        title: title,
        author: author,
        coverUrl: coverUrl,
        genres: genres,
        description: description,
      );
      await _attachCoverUploadIfNeeded(
        session: session,
        item: updated,
        coverUploadPayload: coverUploadPayload,
      );
      await _attachUploadIfNeeded(
        session: session,
        item: updated,
        type: type,
        uploadPayload: uploadPayload,
      );
      final freshUpdatedItem = await _libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
      );
      final resolvedUpdatedItem = await _withFreshCoverUrl(
        session: session,
        item: freshUpdatedItem,
      );
      await fetchLibrary();
      return resolvedUpdatedItem;
    } on ApiException catch (e) {
      _libraryError = e.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      _libraryError = "Не удалось обновить произведение";
      notifyListeners();
      rethrow;
    }
  }

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
    final session = _session;
    if (session == null) {
      throw ApiException("Сессия авторизации не найдена");
    }
    _libraryError = null;
    notifyListeners();
    try {
      final createdItem = await _libraryRepository.createMediaItem(
        accessToken: session.accessToken,
        type: type,
        title: title,
        author: author,
        coverUrl: coverUrl,
        genres: genres,
      );
      if (description != null && description.trim().isNotEmpty) {
        await _libraryRepository.updateMediaItem(
          accessToken: session.accessToken,
          mediaItemId: createdItem.id,
          description: description,
        );
      }
      await _attachUploadIfNeeded(
        session: session,
        item: createdItem,
        type: type,
        uploadPayload: uploadPayload,
      );
      await _attachCoverUploadIfNeeded(
        session: session,
        item: createdItem,
        coverUploadPayload: coverUploadPayload,
      );
      await _libraryRepository.createMediaLink(
        accessToken: session.accessToken,
        sourceMediaId: sourceMediaItemId,
        targetMediaId: createdItem.id,
        relationType: "related",
      );
      await fetchLibrary();
      final fresh = await _libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: createdItem.id,
      );
      return fresh;
    } on ApiException catch (e) {
      _libraryError = e.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      _libraryError = "Не удалось добавить новый формат произведения";
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
      final item = await _libraryRepository.fetchMediaItemById(
        accessToken: session.accessToken,
        mediaItemId: mediaItemId,
      );
      return await _withFreshCoverUrl(session: session, item: item);
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

  Future<String> loadBookContent(MediaListItem item) async {
    if (item.type != "book") {
      throw ApiException("Этот формат не поддерживает чтение текста");
    }
    if (item.id.startsWith("demo-")) {
      final fallback = item.description?.trim();
      if (fallback != null && fallback.isNotEmpty) {
        return fallback;
      }
      return "Для демо-книги текстовый контент не загружен.";
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
        "Для книги не указан media_file_id в metadata_json.",
      );
    }

    final streamInfo = await _libraryRepository.fetchMediaStreamUrl(
      accessToken: session.accessToken,
      fileId: mediaFileId,
    );
    final response = await http
        .get(Uri.parse(streamInfo.streamUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        "Не удалось загрузить содержимое книги (HTTP ${response.statusCode}).",
      );
    }

    final contentType = (response.headers["content-type"] ?? "")
        .toLowerCase();
    if (contentType.contains("application/pdf") ||
        contentType.contains("application/epub+zip")) {
      throw ApiException(
        "Этот формат книги пока не поддерживается для встроенного чтения.",
      );
    }

    String text;
    final looksLikeDocx =
        contentType.contains(
          "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ) ||
        _looksLikeZip(response.bodyBytes);
    if (looksLikeDocx) {
      text = _extractDocxText(response.bodyBytes).trim();
    } else {
      text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    }
    if (text.isEmpty) {
      throw ApiException("Файл книги пустой или не содержит читаемого текста.");
    }
    return text;
  }

  bool _looksLikeZip(List<int> bytes) {
    if (bytes.length < 2) {
      return false;
    }
    return bytes[0] == 0x50 && bytes[1] == 0x4b;
  }

  String _extractDocxText(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);
      ArchiveFile? documentXmlFile;
      for (final file in archive.files) {
        if (file.name == "word/document.xml") {
          documentXmlFile = file;
          break;
        }
      }
      if (documentXmlFile == null) {
        throw ApiException("DOCX не содержит word/document.xml");
      }
      final xmlBytes = documentXmlFile.content;
      final xml = utf8.decode(xmlBytes, allowMalformed: true);
      final normalized =
          xml
              .replaceAll(RegExp(r"<w:tab\s*/>"), "\t")
              .replaceAll(RegExp(r"<w:br\s*/>"), "\n")
              .replaceAll(RegExp(r"</w:p>"), "\n")
              .replaceAll(RegExp(r"<w:p[^>]*>"), "")
              .replaceAll(RegExp(r"</?w:[^>]+>"), "");
      final unescaped = _decodeXmlEntities(normalized);
      return unescaped
          .replaceAll(RegExp(r"\n{3,}"), "\n\n")
          .replaceAll(RegExp(r"[ \t]{2,}"), " ")
          .trim();
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException("Не удалось распарсить DOCX-книгу");
    }
  }

  String _decodeXmlEntities(String text) {
    return text
        .replaceAll("&amp;", "&")
        .replaceAll("&lt;", "<")
        .replaceAll("&gt;", ">")
        .replaceAll("&quot;", '"')
        .replaceAll("&apos;", "'");
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

  void markItemViewed(String mediaItemId) {
    final userId = _currentUserId;
    if (userId == null) {
      return;
    }
    final normalizedId = mediaItemId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final current = _recentlyViewedItemIdsByUser[userId] ?? const <String>[];
    final next = <String>[normalizedId];
    for (final id in current) {
      if (id != normalizedId) {
        next.add(id);
      }
    }
    _recentlyViewedItemIdsByUser = <String, List<String>>{
      ..._recentlyViewedItemIdsByUser,
      userId: next.take(20).toList(growable: false),
    };
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

  Future<void> _attachUploadIfNeeded({
    required AuthSession session,
    required MediaListItem item,
    required String type,
    required MediaUploadPayload? uploadPayload,
  }) async {
    if (uploadPayload == null) {
      return;
    }
    final initUpload = await _libraryRepository.initiateFileUpload(
      accessToken: session.accessToken,
      mediaItemId: item.id,
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
      ...(item.metadataJson ?? const <String, dynamic>{}),
      "media_file_id": initUpload.fileId,
    };
    await _libraryRepository.updateMediaMetadata(
      accessToken: session.accessToken,
      mediaItemId: item.id,
      metadataJson: mergedMetadata,
    );
  }

  Future<void> _attachCoverUploadIfNeeded({
    required AuthSession session,
    required MediaListItem item,
    required MediaUploadPayload? coverUploadPayload,
  }) async {
    if (coverUploadPayload == null) {
      return;
    }
    final initUpload = await _libraryRepository.initiateFileUpload(
      accessToken: session.accessToken,
      mediaItemId: item.id,
      filename: coverUploadPayload.filename,
      contentType: coverUploadPayload.contentType,
      fileSize: coverUploadPayload.bytes.length,
    );
    await _libraryRepository.uploadBytesToPresignedUrl(
      uploadUrl: initUpload.uploadUrl,
      bytes: coverUploadPayload.bytes,
      contentType: coverUploadPayload.contentType,
    );
    await _libraryRepository.completeFileUpload(
      accessToken: session.accessToken,
      fileId: initUpload.fileId,
    );
    final stream = await _libraryRepository.fetchMediaStreamUrl(
      accessToken: session.accessToken,
      fileId: initUpload.fileId,
    );
    final freshItem = await _libraryRepository.fetchMediaItemById(
      accessToken: session.accessToken,
      mediaItemId: item.id,
    );
    final mergedMetadata = <String, dynamic>{
      ...(freshItem.metadataJson ?? const <String, dynamic>{}),
      "cover_file_id": initUpload.fileId,
    };
    await _libraryRepository.updateMediaItem(
      accessToken: session.accessToken,
      mediaItemId: item.id,
      coverUrl: stream.streamUrl,
      metadataJson: mergedMetadata,
    );
  }

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
    _availableGenres = const [
      "Фэнтези",
      "Фантастика",
      "Детектив",
      "Классика",
      "Роман",
      "Нон-фикшн",
    ];
    _usingDemoItems = false;
    _allowDemoFallback = true;
    _searchQuery = "";
    _typeFilter = null;
    _selectedTab = 0;
    _currentUserId = null;
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

  String? _extractUserIdFromAccessToken(String token) {
    try {
      final parts = token.split(".");
      if (parts.length < 2) {
        return null;
      }
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        final sub = json["sub"];
        if (sub is String && sub.trim().isNotEmpty) {
          return sub.trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _stopProgressSyncTimer();
    super.dispose();
  }

  List<String> _normalizeGenres(List<String> genres) {
    final result = <String>[];
    final seen = <String>{};
    for (final raw in genres) {
      final genre = raw.trim();
      if (genre.isEmpty) {
        continue;
      }
      final key = genre.toLowerCase();
      if (seen.contains(key)) {
        continue;
      }
      seen.add(key);
      result.add(genre);
    }
    return result;
  }

  Future<List<MediaListItem>> _withFreshCoverUrls({
    required AuthSession session,
    required List<MediaListItem> items,
  }) async {
    final refreshed = <MediaListItem>[];
    for (final item in items) {
      final resolved = await _withFreshCoverUrl(session: session, item: item);
      refreshed.add(resolved);
    }
    return refreshed;
  }

  Future<MediaListItem> _withFreshCoverUrl({
    required AuthSession session,
    required MediaListItem item,
  }) async {
    final coverFileId = item.coverFileId;
    if (coverFileId == null || coverFileId.isEmpty) {
      return item;
    }
    try {
      final stream = await _libraryRepository.fetchMediaStreamUrl(
        accessToken: session.accessToken,
        fileId: coverFileId,
      );
      if (stream.streamUrl.trim().isEmpty) {
        return item;
      }
      return item.copyWith(coverUrl: stream.streamUrl);
    } on ApiException {
      return item;
    } catch (_) {
      return item;
    }
  }
}
