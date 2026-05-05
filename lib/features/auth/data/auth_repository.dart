import "../../../core/network/api_client.dart";

class AuthSession {
  AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.email,
  });

  final String accessToken;
  final String refreshToken;
  final String email;
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

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
    );
  }
}
