import "../../../core/network/api_client.dart";

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.email,
    required this.displayName,
    this.twofaEnabled = false,
  });

  final String accessToken;
  final String refreshToken;
  final String email;
  final String displayName;
  final bool twofaEnabled;

  AuthSession copyWith({
    String? email,
    String? displayName,
    bool? twofaEnabled,
  }) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      twofaEnabled: twofaEnabled ?? this.twofaEnabled,
    );
  }
}

/// Второй шаг входа: код из письма.
class PendingEmailTwoFa {
  const PendingEmailTwoFa({
    required this.challengeToken,
    required this.email,
    required this.displayName,
    this.message,
  });

  final String challengeToken;
  final String email;
  final String displayName;
  final String? message;
}

class LoginResult {
  const LoginResult({this.session, this.pendingTwoFa});

  final AuthSession? session;
  final PendingEmailTwoFa? pendingTwoFa;
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

  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson("/auth/login", {
      "email": email,
      "password": password,
    });
    final requires2Fa = response["requires_2fa"] == true;
    if (requires2Fa) {
      final challengeToken = response["challenge_token"] as String?;
      if (challengeToken == null || challengeToken.isEmpty) {
        throw ApiException("Некорректный ответ 2FA");
      }
      final em = response["email"] as String? ?? email;
      final dn = response["display_name"] as String?;
      final message = response["message"] as String?;
      return LoginResult(
        pendingTwoFa: PendingEmailTwoFa(
          challengeToken: challengeToken,
          email: em,
          displayName: _normalizeDisplayName(dn, fallbackEmail: em),
          message: message,
        ),
      );
    }

    final accessToken = response["access_token"] as String?;
    final refreshToken = response["refresh_token"] as String?;
    if (accessToken == null || refreshToken == null) {
      throw ApiException("Invalid auth response");
    }

    final dn = response["display_name"] as String?;
    final em = response["email"] as String? ?? email;
    final twofa = response["twofa_enabled"] == true;
    return LoginResult(
      session: AuthSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        email: em,
        displayName: _normalizeDisplayName(dn, fallbackEmail: em),
        twofaEnabled: twofa,
      ),
    );
  }

  Future<AuthSession> verifyEmailTwoFa({
    required String challengeToken,
    required String code,
  }) async {
    final response = await _apiClient.postJson("/auth/2fa/email/verify", {
      "challenge_token": challengeToken,
      "otp_code": code.trim(),
    });
    final accessToken = response["access_token"] as String?;
    final refreshToken = response["refresh_token"] as String?;
    if (accessToken == null || refreshToken == null) {
      throw ApiException("Некорректный ответ после проверки кода");
    }
    final email = response["email"] as String? ?? "";
    final dn = response["display_name"] as String?;
    final twofa = response["twofa_enabled"] == true;
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
      displayName: _normalizeDisplayName(dn, fallbackEmail: email),
      twofaEnabled: twofa,
    );
  }

  /// Повторная отправка письма с кодом (тот же challenge_token).
  Future<void> resendEmailTwoFa({required String challengeToken}) async {
    await _apiClient.postJson("/auth/2fa/email/resend", {
      "challenge_token": challengeToken,
    });
  }

  Future<void> startEmailTwoFaEnable({
    required String accessToken,
    required String currentPassword,
  }) async {
    await _apiClient.postJson(
      "/auth/2fa/email/enable/start",
      {"current_password": currentPassword},
      accessToken: accessToken,
    );
  }

  Future<void> confirmEmailTwoFaEnable({
    required String accessToken,
    required String code,
  }) async {
    await _apiClient.postJson(
      "/auth/2fa/email/enable/confirm",
      {"code": code.trim()},
      accessToken: accessToken,
    );
  }

  Future<void> disableEmailTwoFa({
    required String accessToken,
    required String currentPassword,
  }) async {
    await _apiClient.postJson(
      "/auth/2fa/email/disable",
      {"current_password": currentPassword},
      accessToken: accessToken,
    );
  }

  /// Восстановление сессии по refresh-токену (старт приложения).
  Future<AuthSession> restoreSession({required String refreshToken}) async {
    final response = await _apiClient.postJson("/auth/refresh", {
      "refresh_token": refreshToken,
    });
    final accessToken = response["access_token"] as String?;
    final newRefresh = response["refresh_token"] as String?;
    if (accessToken == null || newRefresh == null) {
      throw ApiException("Некорректный ответ при обновлении сессии");
    }
    final me = await _apiClient.getJson("/auth/me", accessToken: accessToken);
    final email = me["email"] as String? ?? "";
    final dn = me["display_name"] as String?;
    final twofa = me["twofa_enabled"] == true;
    return AuthSession(
      accessToken: accessToken,
      refreshToken: newRefresh,
      email: email,
      displayName: _normalizeDisplayName(dn, fallbackEmail: email),
      twofaEnabled: twofa,
    );
  }

  /// Обновление профиля: имя; смена email требует [currentPassword].
  Future<({String email, String displayName, bool twofaEnabled})> patchProfile({
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
    final twofa = res["twofa_enabled"] == true;
    return (email: outEmail, displayName: outName, twofaEnabled: twofa);
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
