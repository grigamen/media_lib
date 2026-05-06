import "package:flutter/foundation.dart";

import "../core/config/app_config.dart";
import "../core/network/api_client.dart";
import "../features/auth/data/auth_repository.dart";
import "../features/library/data/library_repository.dart";

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

  Future<void> login({
    required String email,
    required String password,
  }) async {
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
    return _demoLibraryItems.where((item) {
      final matchesType = _typeFilter == null || item.type == _typeFilter;
      if (!matchesType) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return item.title.toLowerCase().contains(query) || (item.author ?? "").toLowerCase().contains(query);
    }).toList(growable: false);
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
  }) async {
    final session = _session;
    if (session == null) {
      return;
    }
    _libraryError = null;
    notifyListeners();
    try {
      await _libraryRepository.createMediaItem(
        accessToken: session.accessToken,
        type: type,
        title: title,
        author: author,
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

  void logout() {
    _session = null;
    _authError = null;
    _libraryError = null;
    _items = const [];
    _usingDemoItems = false;
    _searchQuery = "";
    _typeFilter = null;
    _selectedTab = 0;
    notifyListeners();
  }
}
