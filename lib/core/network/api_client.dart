import "dart:convert";

import "package:http/http.dart" as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => "ApiException(statusCode: $statusCode, message: $message)";
}

class ApiClient {
  ApiClient({required this.baseUrl});

  final String baseUrl;

  Uri _uri(String path) => Uri.parse("$baseUrl$path");

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    final response = await http.post(
      _uri(path),
      headers: {
        "Content-Type": "application/json",
        if (accessToken != null) "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode(body),
    );
    return _parseObject(response);
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    String? accessToken,
  }) async {
    final response = await http.get(
      _uri(path),
      headers: {
        if (accessToken != null) "Authorization": "Bearer $accessToken",
      },
    );
    return _parseObject(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    String? accessToken,
  }) async {
    final response = await http.get(
      _uri(path),
      headers: {
        if (accessToken != null) "Authorization": "Bearer $accessToken",
      },
    );
    return _parseList(response);
  }

  Map<String, dynamic> _parseObject(http.Response response) {
    final body = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Object?;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body;
      }
      throw ApiException("Unexpected response format", statusCode: response.statusCode);
    }
    throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode);
  }

  List<dynamic> _parseList(http.Response response) {
    final body = response.body.isEmpty ? const <dynamic>[] : jsonDecode(response.body) as Object?;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is List<dynamic>) {
        return body;
      }
      throw ApiException("Unexpected response format", statusCode: response.statusCode);
    }
    throw ApiException(_extractErrorMessage(body), statusCode: response.statusCode);
  }

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
