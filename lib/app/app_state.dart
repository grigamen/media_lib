// Главное состояние клиента: сессия, каталог, плеер, локальные сторы и настройки UI.
// Детали: app_state_auth.dart, app_state_library.dart, app_state_playback.dart.

import "dart:async";
import "dart:convert";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../core/sync/playback_progress_resolution.dart";

import "../core/config/app_config.dart";
import "../core/local/auth_token_store.dart";
import "../core/local/catalog_cache_store.dart";
import "../core/local/media_lib_database.dart";
import "../core/local/progress_local_store.dart";
import "../core/local/author_book_local_file_store.dart";
import "../core/local/recently_viewed_local_store.dart";
import "../core/network/api_client.dart";
import "../features/auth/data/auth_repository.dart";
import "../features/library/data/library_repository.dart";
import "../features/library/data/library_filters.dart";
import "../features/library/data/library_sort.dart";
import "../features/shelves/data/shelf_models.dart";
import "../features/shelves/data/shelf_repository.dart";

import "media_upload_payload.dart";
import "playback_session.dart";

import "services/admin_catalog_service.dart";
import "services/book_content_loader.dart";
import "services/book_offline_cache_stub.dart"
    if (dart.library.io) "services/book_offline_cache_io.dart";
import "services/book_file_reader_stub.dart"
    if (dart.library.io) "services/book_file_reader_io.dart";
import "services/cover_url_refresh_service.dart";
import "services/demo_library_data.dart";
import "services/media_catalog_utils.dart";
import "services/playback_progress_sync.dart";
import "services/presigned_upload_tracker.dart";

export "media_upload_payload.dart";
export "playback_session.dart";

part "app_state_library.dart";
part "app_state_playback.dart";
part "app_state_shelves.dart";
part "app_state_auth.dart";
part "app_state_book_local.dart";

mixin _AppStateRefs on ChangeNotifier {
  /// Указатель на полный [AppState] из миксинов-частей ([_s]).
  AppState get _s => this as AppState;
}

/// Локально скачанная книга на устройстве текущего пользователя.
class DownloadedBookDeviceItem {
  const DownloadedBookDeviceItem({
    required this.mediaItemId,
    required this.title,
    required this.author,
    required this.filename,
    required this.filePath,
    required this.updatedAt,
    this.coverUrl,
  });

  final String mediaItemId;
  final String title;
  final String author;
  final String filename;
  final String filePath;
  final DateTime updatedAt;
  final String? coverUrl;
}

/// Корневой [ChangeNotifier] приложения; поля и геттеры здесь, поведение — в mixins `part`.
class AppState extends ChangeNotifier
    with
        _AppStateRefs,
        _AppStateAuth,
        _AppStateLibrary,
        _AppStatePlayback,
        _AppStateShelves,
        _AppStateBookLocal {
  /// Создаёт HTTP-клиент, репозитории, вспомогательные сервисы и запускает [_bootstrap].
  AppState()
    : _apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl),
      _isDarkMode = false {
    _authRepository = AuthRepository(_apiClient);
    _libraryRepository = LibraryRepository(_apiClient);
    _shelfRepository = ShelfRepository(_apiClient);
    _coverRefresh = CoverUrlRefreshService(_libraryRepository);
    _adminCatalog = AdminCatalogService(
      library: _libraryRepository,
      coverRefresh: _coverRefresh,
      onChanged: notifyListeners,
    );
    _uploadTracker = PresignedUploadTracker(onChanged: notifyListeners);
    _bookContentLoader = BookContentLoader(_libraryRepository);
    _playbackPusher = PlaybackProgressPusher(_libraryRepository);
    _pendingProgressFlush = PendingProgressMirrorFlush(_libraryRepository);
    unawaited(_bootstrap());
  }

  final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final LibraryRepository _libraryRepository;
  late final ShelfRepository _shelfRepository;
  late final CoverUrlRefreshService _coverRefresh;
  late final AdminCatalogService _adminCatalog;
  late final PresignedUploadTracker _uploadTracker;
  late final BookContentLoader _bookContentLoader;
  late final PlaybackProgressPusher _playbackPusher;
  late final PendingProgressMirrorFlush _pendingProgressFlush;
  final PlaybackProgressSyncTimer _playbackSyncTimer = PlaybackProgressSyncTimer();
  final AuthTokenStore _authTokenStore = AuthTokenStore();

  bool _bootstrapComplete = false;

  bool _isDarkMode;
  bool _isAuthLoading = false;
  bool _isLibraryLoading = false;
  String? _authError;
  String? _libraryError;
  AuthSession? _session;
  String? _pendingTwoFaChallengeToken;
  String? _pendingTwoFaEmail;
  String? _pendingTwoFaDisplayName;
  String? _pendingTwoFaMessage;
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

  /// Личные оценки демо-произведений (ключ — id карточки demo-*).
  final Map<String, int> _demoUserRatingsByMediaId = {};

  /// Кэш последних оценок с сервера (ключ — media_item_id).
  final Map<String, int?> _userRatingCacheByMediaId = {};

  /// Счётчик просмотров для demo-карточек (ключ — media_item_id).
  final Map<String, int> _demoViewsCountByMediaId = {};

  /// Время последнего открытия полки (мс UTC) — для порядка на главной.
  final Map<String, int> _shelfLastOpenedAtMs = {};

  /// После первого непустого ответа API пустой список больше не заменяется демо-данными.
  bool _sawNonEmptyServerLibrary = false;
  String _searchQuery = "";
  List<String> _selectedTypes = const [];
  List<String> _selectedGenres = const [];
  LibraryRatingCriteria _libraryRatingCriteria = LibraryRatingCriteria.any;
  LibraryViewsCriteria _libraryViewsCriteria = LibraryViewsCriteria.any;
  LibrarySortField _librarySortField = LibrarySortField.title;
  bool _librarySortDescending = false;
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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Map<String, List<String>> _recentlyViewedItemIdsByUser = const {};
  String? _currentUserId;
  bool _isAdminUser = false;

  CatalogCacheStore? _catalogCache;
  ProgressLocalStore? _progressStore;
  RecentlyViewedLocalStore? _recentlyViewedStore;
  AuthorBookLocalFileStore? _authorBookLocalStore;

  /// Все произведения, созданные текущим пользователем ([GET /media-items?mine=true], total).
  int _ownedWorksTotal = 0;

  bool get isBootstrapComplete => _bootstrapComplete;

  bool get isDarkMode => _isDarkMode;
  bool get isAuthenticated => _session != null;
  bool get isAuthLoading => _isAuthLoading;
  bool get isLibraryLoading => _isLibraryLoading;
  String? get authError => _authError;
  String? get libraryError => _libraryError;

  bool get hasPendingEmailTwoFa =>
      _pendingTwoFaChallengeToken != null &&
      _pendingTwoFaChallengeToken!.isNotEmpty;

  String? get pendingTwoFaEmail => _pendingTwoFaEmail;
  String? get pendingTwoFaDisplayName => _pendingTwoFaDisplayName;
  String? get pendingTwoFaMessage => _pendingTwoFaMessage;

  bool get userTwofaEnabled => _session?.twofaEnabled ?? false;

  String get userEmail => _session?.email ?? "";

  String get userDisplayName => _session?.displayName ?? "";
  List<MediaListItem> get items => _items;
  List<MediaListItem> get adminPendingItems => _adminCatalog.state.pendingItems;
  List<MediaListItem> get adminAllItems => _adminCatalog.state.allItems;
  bool get adminPendingHasMore => _adminCatalog.pendingHasMore;
  bool get adminAllHasMore => _adminCatalog.allHasMore;
  bool get isAdminPendingLoadingMore =>
      _adminCatalog.state.isPendingLoadingMore;
  bool get isAdminAllLoadingMore => _adminCatalog.state.isAllLoadingMore;
  bool get isAdminCatalogLoading => _adminCatalog.state.isCatalogLoading;
  String? get adminCatalogError => _adminCatalog.state.error;
  List<String> get availableGenres => _availableGenres;
  bool get usingDemoItems => _usingDemoItems;
  String get searchQuery => _searchQuery;

  List<String> get selectedTypes => List.unmodifiable(_selectedTypes);

  List<String> get selectedGenres => List.unmodifiable(_selectedGenres);

  LibraryRatingCriteria get libraryRatingCriteria => _libraryRatingCriteria;

  LibraryViewsCriteria get libraryViewsCriteria => _libraryViewsCriteria;

  LibrarySortField get librarySortField => _librarySortField;

  bool get librarySortDescending => _librarySortDescending;

  /// Одна выбранная категория для чипов на экране библиотеки, иначе «Все».
  String? get libraryTypeFilterChip =>
      _selectedTypes.length == 1 ? _selectedTypes.first : null;

  String? get typeFilter => libraryTypeFilterChip;
  int get selectedTab => _selectedTab;
  PlaybackLoadState get playbackLoadState => _playbackLoadState;
  String? get playbackError => _playbackError;
  String? get activePlaybackMediaItemId => _activePlaybackMediaItemId;
  int get playbackPositionSeconds => _playbackPositionSeconds;
  int? get playbackDurationSeconds => _playbackDurationSeconds;
  bool get pendingPlaybackSync => _pendingPlaybackSync;
  double get playbackSpeed => _playbackSpeed;
  String? get currentUserId => _currentUserId;
  bool get isAdminUser => _isAdminUser;

  int get ownedWorksTotal => _ownedWorksTotal;

  bool get hasOwnedWorks => _ownedWorksTotal > 0;

  double? get presignedUploadProgress => _uploadTracker.displayProgress;
  List<MediaListItem> get recentlyViewedItems {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }
    final recentIds = _recentlyViewedItemIdsByUser[userId] ?? const <String>[];
    if (recentIds.isEmpty) {
      return const [];
    }
    final byId = <String, MediaListItem>{
      for (final item in _items) item.id: item,
    };
    final seenWorkKeys = <String>{};
    final result = <MediaListItem>[];
    for (final id in recentIds) {
      final item = byId[id];
      if (item == null) {
        continue;
      }
      final workKey = mediaWorkGroupKey(item);
      if (seenWorkKeys.add(workKey)) {
        result.add(item);
      }
    }
    return result;
  }

  static const String _prefsKeyDarkMode = "ui.dark_mode";

  /// Переключает тёмную тему и сохраняет выбор в SharedPreferences.
  void toggleTheme(bool enabled) {
    _isDarkMode = enabled;
    notifyListeners();
    unawaited(_persistThemePreference());
  }

  /// Читает сохранённую тему при старте ([_bootstrap] через вызов из auth-части).
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_prefsKeyDarkMode);
      if (stored == null) {
        return;
      }
      _isDarkMode = stored;
    } catch (_) {}
  }

  /// Сохраняет флаг тёмной темы в SharedPreferences.
  Future<void> _persistThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyDarkMode, _isDarkMode);
    } catch (_) {}
  }

  /// Нижняя навигация: индекс вкладки 0…4 с clamp.
  void setSelectedTab(int value) {
    final tab = value.clamp(0, 4);
    _selectedTab = tab;
    if (tab == 0 && _session != null) {
      unawaited(fetchShelves());
    }
    notifyListeners();
  }

  /// Отмена подписки на сеть и остановка таймера синхронизации прогресса.
  @override
  void dispose() {
    _stopConnectivityWatcher();
    _stopProgressSyncTimer();
    super.dispose();
  }
}
