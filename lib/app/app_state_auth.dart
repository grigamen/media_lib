part of 'app_state.dart';

/// Авторизация, 2FA, профиль, локальные SQLite-сторы и сетевой офлайн/онлайн для прогресса.
mixin _AppStateAuth on _AppStateRefs {
  /// Старт приложения: тема из prefs, восстановление refresh-токена и сессии.
  Future<void> _bootstrap() async {
    try {
      await _s._loadThemePreference();
      notifyListeners();
      final refresh = await _s._authTokenStore.readRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        try {
          final session = await _s._authRepository.restoreSession(
            refreshToken: refresh,
          );
          await _activateSession(session, resetLibraryState: true);
        } on ApiException {
          await _s._authTokenStore.clear();
          _s._session = null;
          _s._currentUserId = null;
          _s._isAdminUser = false;
        } catch (_) {
          await _s._authTokenStore.clear();
          _s._session = null;
          _s._currentUserId = null;
          _s._isAdminUser = false;
        }
      }
    } catch (_) {
      await _s._authTokenStore.clear();
    } finally {
      _s._bootstrapComplete = true;
      notifyListeners();
    }
  }

  /// Устанавливает сессию, роли из JWT, открывает локальное хранилище и тянет каталог.
  Future<void> _activateSession(
    AuthSession session, {
    required bool resetLibraryState,
  }) async {
    _s._session = session;
    _clearPendingEmailTwoFa();
    _s._currentUserId = _extractUserIdFromAccessToken(session.accessToken);
    _s._isAdminUser = _extractIsAdminFromAccessToken(session.accessToken);
    if (resetLibraryState) {
      _s._sawNonEmptyServerLibrary = false;
      _s._adminCatalog.reset();
    }
    await _s._authTokenStore.saveSession(session);
    await _ensureLocalPersistence();
    await _hydrateRecentlyViewedFromDisk();
    _startConnectivityWatcherIfNeeded();
    await _s.fetchLibrary();
  }

  /// Сбрасывает состояние «ожидается код 2FA по почте» после успешного входа или отмены.
  void _clearPendingEmailTwoFa() {
    _s._pendingTwoFaChallengeToken = null;
    _s._pendingTwoFaEmail = null;
    _s._pendingTwoFaDisplayName = null;
    _s._pendingTwoFaMessage = null;
  }

  /// Подтверждает одноразовый код после входа с включённой email-2FA.
  Future<void> submitEmailTwoFaCode(String code) async {
    final token = _s._pendingTwoFaChallengeToken;
    if (token == null || token.isEmpty) {
      return;
    }
    _s._isAuthLoading = true;
    _s._authError = null;
    notifyListeners();
    try {
      final session = await _s._authRepository.verifyEmailTwoFa(
        challengeToken: token,
        code: code,
      );
      await _activateSession(session, resetLibraryState: true);
    } on ApiException catch (e) {
      _s._authError = e.message;
    } catch (_) {
      _s._authError = "Не удалось подтвердить код";
    } finally {
      _s._isAuthLoading = false;
      notifyListeners();
    }
  }

  /// Повторная отправка OTP на почту по текущему challenge-токену.
  Future<void> resendEmailTwoFaCode() async {
    final token = _s._pendingTwoFaChallengeToken;
    if (token == null || token.isEmpty) {
      return;
    }
    _s._authError = null;
    notifyListeners();
    try {
      await _s._authRepository.resendEmailTwoFa(challengeToken: token);
    } on ApiException catch (e) {
      _s._authError = e.message;
    } catch (_) {
      _s._authError = "Не удалось отправить код повторно";
    }
    notifyListeners();
  }

  /// Отменяет сценарий входа с 2FA (пользователь вернётся к форме логина).
  void cancelEmailTwoFaLogin() {
    _clearPendingEmailTwoFa();
    _s._authError = null;
    notifyListeners();
  }

  /// Шаг 1 включения 2FA из профиля: проверка пароля и отправка кода.
  Future<void> startTwoFaEnableFromProfile(String currentPassword) async {
    final session = _s._session;
    if (session == null) {
      throw ApiException("Нет сессии");
    }
    await _s._authRepository.startEmailTwoFaEnable(
      accessToken: session.accessToken,
      currentPassword: currentPassword,
    );
  }

  /// Шаг 2 включения 2FA: проверка кода и обновление флага в локальной сессии.
  Future<void> confirmTwoFaEnableFromProfile(String code) async {
    final session = _s._session;
    if (session == null) {
      throw ApiException("Нет сессии");
    }
    await _s._authRepository.confirmEmailTwoFaEnable(
      accessToken: session.accessToken,
      code: code,
    );
    _s._session = session.copyWith(twofaEnabled: true);
    await _s._authTokenStore.saveSession(_s._session!);
    notifyListeners();
  }

  /// Выключает email-2FA при верном текущем пароле.
  Future<void> disableTwoFaFromProfile(String currentPassword) async {
    final session = _s._session;
    if (session == null) {
      throw ApiException("Нет сессии");
    }
    await _s._authRepository.disableEmailTwoFa(
      accessToken: session.accessToken,
      currentPassword: currentPassword,
    );
    _s._session = session.copyWith(twofaEnabled: false);
    await _s._authTokenStore.saveSession(_s._session!);
    notifyListeners();
  }

  /// Регистрация нового пользователя и автоматический вход (или переход к 2FA).
  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _s._isAuthLoading = true;
    _s._authError = null;
    notifyListeners();
    try {
      await _s._authRepository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      final loginResult = await _s._authRepository.login(
        email: email,
        password: password,
      );
      final sess = loginResult.session;
      if (sess != null) {
        _clearPendingEmailTwoFa();
        await _activateSession(sess, resetLibraryState: true);
      } else if (loginResult.pendingTwoFa != null) {
        final p = loginResult.pendingTwoFa!;
        _s._pendingTwoFaChallengeToken = p.challengeToken;
        _s._pendingTwoFaEmail = p.email;
        _s._pendingTwoFaDisplayName = p.displayName;
        _s._pendingTwoFaMessage = p.message;
      }
    } on ApiException catch (e) {
      _s._authError = e.message;
    } catch (_) {
      _s._authError = "Не удалось выполнить регистрацию";
    } finally {
      _s._isAuthLoading = false;
      notifyListeners();
    }
  }

  /// Вход по email/паролю с поддержкой промежуточного состояния 2FA.
  Future<void> login({required String email, required String password}) async {
    _s._isAuthLoading = true;
    _s._authError = null;
    notifyListeners();
    try {
      final loginResult = await _s._authRepository.login(
        email: email,
        password: password,
      );
      final sess = loginResult.session;
      if (sess != null) {
        _clearPendingEmailTwoFa();
        await _activateSession(sess, resetLibraryState: true);
      } else if (loginResult.pendingTwoFa != null) {
        final p = loginResult.pendingTwoFa!;
        _s._pendingTwoFaChallengeToken = p.challengeToken;
        _s._pendingTwoFaEmail = p.email;
        _s._pendingTwoFaDisplayName = p.displayName;
        _s._pendingTwoFaMessage = p.message;
      }
    } on ApiException catch (e) {
      _s._authError = e.message;
    } catch (_) {
      _s._authError = "Не удалось выполнить вход";
    } finally {
      _s._isAuthLoading = false;
      notifyListeners();
    }
  }

  /// Добавляет просмотр в «Недавние» (память + SQLite, не более 20 id).
  void markItemViewed(String mediaItemId) {
    final userId = _s._currentUserId;
    if (userId == null) {
      return;
    }
    final normalizedId = mediaItemId.trim();
    if (normalizedId.isEmpty) {
      return;
    }
    final current = _s._recentlyViewedItemIdsByUser[userId] ?? const <String>[];
    final next = <String>[normalizedId];
    for (final id in current) {
      if (id != normalizedId) {
        next.add(id);
      }
    }
    final persisted = next.take(20).toList(growable: false);
    _s._recentlyViewedItemIdsByUser = <String, List<String>>{
      ..._s._recentlyViewedItemIdsByUser,
      userId: persisted,
    };
    notifyListeners();
    final store = _s._recentlyViewedStore;
    if (store != null) {
      unawaited(store.saveItemIds(userId, persisted));
    }
  }

  /// PATCH профиля: имя, смена email с подтверждением паролем.
  Future<void> updateUserProfile({
    required String displayName,
    String? newEmail,
    String? currentPasswordForEmail,
  }) async {
    final session = _s._session;
    if (session == null) {
      return;
    }
    final emailTrim = newEmail?.trim();
    final emailChanged =
        emailTrim != null &&
        emailTrim.isNotEmpty &&
        emailTrim.toLowerCase() != session.email.toLowerCase();
    if (emailChanged &&
        (currentPasswordForEmail == null || currentPasswordForEmail.isEmpty)) {
      throw ApiException("Укажите текущий пароль для смены email");
    }
    final result = await _s._authRepository.patchProfile(
      accessToken: session.accessToken,
      displayName: displayName,
      currentEmail: session.email,
      newEmail: emailChanged ? emailTrim : null,
      currentPassword: emailChanged ? currentPasswordForEmail : null,
    );
    _s._session = session.copyWith(
      email: result.email,
      displayName: result.displayName,
      twofaEnabled: result.twofaEnabled,
    );
    await _s._authTokenStore.saveSession(_s._session!);
    notifyListeners();
  }

  /// Смена пароля на сервере при активной сессии.
  Future<void> changeUserPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final session = _s._session;
    if (session == null) {
      throw ApiException("Сессия недействительна. Выйдите и войдите снова.");
    }
    await _s._authRepository.changePassword(
      accessToken: session.accessToken,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Полный выход: чистит токены, списки, плеер и при необходимости локальные данные пользователя.
  void logout() {
    final userIdForPurge = _s._currentUserId;
    _stopConnectivityWatcher();
    _s._stopProgressSyncTimer();
    unawaited(_s._authTokenStore.clear());
    _s._session = null;
    _clearPendingEmailTwoFa();
    _s._authError = null;
    _s._libraryError = null;
    _s._items = const [];
    _s._adminCatalog.reset();
    _s._availableGenres = const [
      "Фэнтези",
      "Фантастика",
      "Детектив",
      "Классика",
      "Роман",
      "Нон-фикшн",
    ];
    _s._usingDemoItems = false;
    _s._allowDemoFallback = true;
    _s._sawNonEmptyServerLibrary = false;
    _s._searchQuery = "";
    _s._selectedTypes = const [];
    _s._selectedGenres = const [];
    _s._librarySortField = LibrarySortField.title;
    _s._librarySortDescending = false;
    _s._selectedTab = 0;
    _s._currentUserId = null;
    _s._isAdminUser = false;
    _s._ownedWorksTotal = 0;
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
    if (userIdForPurge != null) {
      unawaited(_purgeLocalUserData(userIdForPurge));
    }
  }

  /// Лениво открывает общую БД и создаёт сторы кэша каталога, прогресса и «недавних».
  Future<void> _ensureLocalPersistence() async {
    if (_s._catalogCache != null &&
        _s._progressStore != null &&
        _s._recentlyViewedStore != null) {
      return;
    }
    try {
      final db = await MediaLibDatabase.open();
      _s._catalogCache = CatalogCacheStore(db);
      _s._progressStore = ProgressLocalStore(db);
      _s._recentlyViewedStore = RecentlyViewedLocalStore(db);
    } catch (_) {
      _s._catalogCache = null;
      _s._progressStore = null;
      _s._recentlyViewedStore = null;
    }
  }

  /// Поднимает список недавних id с диска после входа пользователя.
  Future<void> _hydrateRecentlyViewedFromDisk() async {
    final userId = _s._currentUserId;
    final store = _s._recentlyViewedStore;
    if (userId == null || store == null) {
      return;
    }
    try {
      final ids = await store.loadItemIds(userId);
      if (ids == null || ids.isEmpty) {
        return;
      }
      _s._recentlyViewedItemIdsByUser = <String, List<String>>{
        ..._s._recentlyViewedItemIdsByUser,
        userId: ids.take(20).toList(growable: false),
      };
    } catch (_) {}
  }

  /// Слушает восстановление сети и пытается сбросить отложенный прогресс на сервер.
  void _startConnectivityWatcherIfNeeded() {
    if (_s._session == null || _s._connectivitySub != null) {
      return;
    }
    _s._connectivitySub = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final offline =
          results.isEmpty || results.every((r) => r == ConnectivityResult.none);
      if (offline) {
        return;
      }
      unawaited(() async {
        final syncedAny = await _flushPendingProgressIfOnline();
        if (syncedAny) {
          notifyListeners();
        }
      }());
    });
  }

  /// Снимает подписку на connectivity (при логауте / dispose).
  void _stopConnectivityWatcher() {
    _s._connectivitySub?.cancel();
    _s._connectivitySub = null;
  }

  /// Пробует отправить на сервер прогресс, накопленный локально при офлайне.
  Future<bool> _flushPendingProgressIfOnline() async {
    final session = _s._session;
    final userId = _s._currentUserId;
    final store = _s._progressStore;
    if (session == null || userId == null || store == null) {
      return false;
    }
    return _s._pendingProgressFlush.flush(
      session: session,
      userId: userId,
      progressStore: store,
    );
  }

  /// Удаляет локальный кэш каталога, прогресса и недавних для указанного пользователя.
  Future<void> _purgeLocalUserData(String userId) async {
    await _ensureLocalPersistence();
    try {
      await _s._catalogCache?.clearForUser(userId);
      await _s._progressStore?.clearForUser(userId);
      await _s._recentlyViewedStore?.clearForUser(userId);
    } catch (_) {}
  }

  /// Достаёт `sub` из JWT access-токена (без проверки подписи — только для UI-связки user id).
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

  /// Читает кастомный claim `adm` из JWT (признак администратора).
  bool _extractIsAdminFromAccessToken(String token) {
    try {
      final parts = token.split(".");
      if (parts.length < 2) {
        return false;
      }
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) {
        final adm = json["adm"];
        return adm == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
