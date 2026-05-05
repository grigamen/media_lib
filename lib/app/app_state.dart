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
  int _selectedTab = 0;

  bool get isDarkMode => _isDarkMode;
  bool get isAuthenticated => _session != null;
  bool get isAuthLoading => _isAuthLoading;
  bool get isLibraryLoading => _isLibraryLoading;
  String? get authError => _authError;
  String? get libraryError => _libraryError;
  String get userEmail => _session?.email ?? "";
  List<MediaListItem> get items => _items;
  int get selectedTab => _selectedTab;

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
      _items = await _libraryRepository.fetchMediaItems(accessToken: session.accessToken);
    } on ApiException catch (e) {
      _libraryError = e.message;
    } catch (_) {
      _libraryError = "Не удалось загрузить библиотеку";
    } finally {
      _isLibraryLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _session = null;
    _authError = null;
    _libraryError = null;
    _items = const [];
    _selectedTab = 0;
    notifyListeners();
  }
}
