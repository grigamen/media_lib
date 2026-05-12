import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../../features/auth/data/auth_repository.dart";

/// Хранение токенов и профиля между запусками (Keychain / Keystore).
class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final FlutterSecureStorage _storage;

  static const _keyRefresh = "medialib_auth_refresh";
  static const _keyAccess = "medialib_auth_access";
  static const _keyEmail = "medialib_auth_email";
  static const _keyDisplayName = "medialib_auth_display_name";

  Future<void> saveSession(AuthSession session) async {
    await Future.wait<void>([
      _storage.write(key: _keyRefresh, value: session.refreshToken),
      _storage.write(key: _keyAccess, value: session.accessToken),
      _storage.write(key: _keyEmail, value: session.email),
      _storage.write(key: _keyDisplayName, value: session.displayName),
    ]);
  }

  Future<String?> readRefreshToken() => _storage.read(key: _keyRefresh);

  Future<void> clear() async {
    await Future.wait<void>([
      _storage.delete(key: _keyRefresh),
      _storage.delete(key: _keyAccess),
      _storage.delete(key: _keyEmail),
      _storage.delete(key: _keyDisplayName),
    ]);
  }
}
