import "dart:async";
import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

/// Ошибка API с человекочитаемым [message] и опциональным HTTP-кодом.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      "ApiException(statusCode: $statusCode, message: $message)";
}

/// HTTP-клиент к backend: JSON-запросы, Bearer, единый таймаут и разбор [ApiException].
class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 15);

  Uri _uri(String path) => Uri.parse("$baseUrl$path");

  bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == "localhost" || normalized == "127.0.0.1";
  }

  bool _canTryAndroidEmulatorFallback(Uri uri) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return _isLoopbackHost(uri.host);
  }

  Uri _toAndroidEmulatorUri(Uri uri) => uri.replace(host: "10.0.2.2");

  Future<http.Response> _sendWithFallback(
    String path,
    Future<http.Response> Function(Uri uri) send,
  ) async {
    final primary = _uri(path);
    final candidates = <Uri>[primary];
    if (_canTryAndroidEmulatorFallback(primary)) {
      candidates.add(_toAndroidEmulatorUri(primary));
    }

    var sawTimeout = false;
    for (final uri in candidates) {
      try {
        return await send(uri).timeout(_requestTimeout);
      } on TimeoutException {
        sawTimeout = true;
      } on Exception {
        // Попробуем следующий endpoint (например 10.0.2.2 для эмулятора).
      }
    }

    if (sawTimeout) {
      throw ApiException(
        "Сервер не отвечает (таймаут 15 сек). Проверьте backend.",
      );
    }
    throw ApiException(
      "Сетевая ошибка. Проверьте API_BASE_URL и запущен ли backend.",
    );
  }

  /// POST с телом JSON; опционально Authorization.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final response = await _sendWithFallback(
      path,
      (uri) => http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (accessToken != null) "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode(body),
      ),
    );
    return _parseObject(response);
  }

  /// PUT JSON (например прогресс воспроизведения).
  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final response = await _sendWithFallback(
      path,
      (uri) => http.put(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (accessToken != null) "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode(body),
      ),
    );
    return _parseObject(response);
  }

  /// PATCH JSON (частичное обновление сущностей).
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final response = await _sendWithFallback(
      path,
      (uri) => http.patch(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (accessToken != null) "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode(body),
      ),
    );
    return _parseObject(response);
  }

  /// GET с ответом-объектом JSON.
  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
  }) async {
    final response = await _sendWithFallback(
      path,
      (uri) => http.get(
        uri,
        headers: {
          if (accessToken != null) "Authorization": "Bearer $accessToken",
        },
      ),
    );
    return _parseObject(response);
  }

  /// GET, тело — JSON-массив.
  Future<List<dynamic>> getJsonList(String path, {String? accessToken}) async {
    final response = await _sendWithFallback(
      path,
      (uri) => http.get(
        uri,
        headers: {
          if (accessToken != null) "Authorization": "Bearer $accessToken",
        },
      ),
    );
    return _parseList(response);
  }

  /// DELETE; для 204 может вернуться пустой объект после разбора.
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    String? accessToken,
  }) async {
    final response = await _sendWithFallback(
      path,
      (uri) => http.delete(
        uri,
        headers: {
          if (accessToken != null) "Authorization": "Bearer $accessToken",
        },
      ),
    );
    return _parseObject(response);
  }

  /// Успех: Map; иначе [ApiException] с `detail` из тела при ошибке.
  Map<String, dynamic> _parseObject(http.Response response) {
    final Object? body;
    try {
      body =
          response.body.isEmpty
              ? const <String, dynamic>{}
              : jsonDecode(response.body) as Object?;
    } on FormatException {
      throw ApiException(
        "Сервер вернул ответ не в формате JSON (код ${response.statusCode}). "
        "Часто это страница ошибки nginx или сбой backend — смотрите journalctl.",
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body;
      }
      throw ApiException(
        "Unexpected response format",
        statusCode: response.statusCode,
      );
    }
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
    );
  }

  /// Аналог [_parseObject] для корневого JSON-массива.
  List<dynamic> _parseList(http.Response response) {
    final Object? body;
    try {
      body =
          response.body.isEmpty
              ? const <dynamic>[]
              : jsonDecode(response.body) as Object?;
    } on FormatException {
      throw ApiException(
        "Сервер вернул ответ не в формате JSON (код ${response.statusCode}). "
        "Часто это страница ошибки nginx или сбой backend — смотрите journalctl.",
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is List<dynamic>) {
        return body;
      }
      throw ApiException(
        "Unexpected response format",
        statusCode: response.statusCode,
      );
    }
    throw ApiException(
      _extractErrorMessage(body),
      statusCode: response.statusCode,
    );
  }

  /// Достаёт FastAPI `detail` из тела ошибки.
  String _extractErrorMessage(Object? body) {
    if (body is Map<String, dynamic>) {
      final detail = body["detail"];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    return "Request failed";
  }
}
