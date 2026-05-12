import "../../../core/network/api_client.dart";

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.email,
    required this.displayName,
  });

  final String accessToken;
  final String refreshToken;
  final String email;
  final String displayName;

  AuthSession copyWith({String? email, String? displayName}) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }
}

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _apiClient.postJson("/auth/register", {
      "email": email,
      "password": password,
      "display_name": displayName,
    });
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson("/auth/login", {
      "email": email,
      "password": password,
    });
    final requires2Fa = response["requires_2fa"] == true;
    if (requires2Fa) {
      throw ApiException("2FA is enabled. Week 5 UI supports basic login only.");
    }

    final accessToken = response["access_token"] as String?;
    final refreshToken = response["refresh_token"] as String?;
    if (accessToken == null || refreshToken == null) {
      throw ApiException("Invalid auth response");
    }

    final dn = response["display_name"] as String?;
    final em = response["email"] as String? ?? email;
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: em,
      displayName: _normalizeDisplayName(dn, fallbackEmail: em),
    );
  }

  /// Обновление профиля: имя; смена email требует [currentPassword].
  Future<({String email, String displayName})> patchProfile({
    required String accessToken,
    required String displayName,
    required String currentEmail,
    String? newEmail,
    String? currentPassword,
  }) async {
    final body = <String, dynamic>{"display_name": displayName.trim()};
    final ne = newEmail?.trim();
    if (ne != null && ne.isNotEmpty) {
      body["email"] = ne;
      if (currentPassword != null && currentPassword.isNotEmpty) {
        body["current_password"] = currentPassword;
      }
    }
    final res = await _apiClient.patchJson("/auth/me", body, accessToken: accessToken);
    final outEmail = res["email"] as String? ?? currentEmail;
    final outName = res["display_name"] as String? ?? displayName.trim();
    return (email: outEmail, displayName: outName);
  }

  Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.postJson(
      "/auth/change-password",
      {
        "current_password": currentPassword,
        "new_password": newPassword,
      },
      accessToken: accessToken,
    );
  }
}

String _normalizeDisplayName(String? raw, {required String fallbackEmail}) {
  final t = raw?.trim() ?? "";
  if (t.isNotEmpty) {
    return t;
  }
  final at = fallbackEmail.indexOf("@");
  return at > 0 ? fallbackEmail.substring(0, at) : fallbackEmail;
}
