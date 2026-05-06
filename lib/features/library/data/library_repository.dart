import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:http/http.dart" as http;

import "../../../core/network/api_client.dart";

class MediaListItem {
  const MediaListItem({
    required this.id,
    required this.title,
    required this.type,
    this.author,
    this.description,
    this.metadataJson,
  });

  final String id;
  final String title;
  final String type;
  final String? author;
  final String? description;
  final Map<String, dynamic>? metadataJson;

  String? get mediaFileId {
    final metadata = metadataJson;
    if (metadata == null) {
      return null;
    }
    final direct = metadata["media_file_id"];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }
    final fallback = metadata["file_id"];
    if (fallback is String && fallback.trim().isNotEmpty) {
      return fallback.trim();
    }
    return null;
  }

  factory MediaListItem.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json["metadata_json"];
    final metadata =
        rawMetadata is Map<String, dynamic>
            ? rawMetadata
            : (rawMetadata is Map ? rawMetadata.cast<String, dynamic>() : null);
    return MediaListItem(
      id: json["id"] as String? ?? "",
      title: json["title"] as String? ?? "Untitled",
      type: json["type"] as String? ?? "unknown",
      author: json["author"] as String?,
      description: json["description"] as String?,
      metadataJson: metadata,
    );
  }
}

class MediaLinkItem {
  MediaLinkItem({
    required this.id,
    required this.sourceMediaId,
    required this.targetMediaId,
    required this.relationType,
  });

  final String id;
  final String sourceMediaId;
  final String targetMediaId;
  final String relationType;

  factory MediaLinkItem.fromJson(Map<String, dynamic> json) {
    return MediaLinkItem(
      id: json["id"] as String? ?? "",
      sourceMediaId: json["source_media_id"] as String? ?? "",
      targetMediaId: json["target_media_id"] as String? ?? "",
      relationType: json["relation_type"] as String? ?? "related",
    );
  }
}

class MediaProgress {
  const MediaProgress({
    required this.mediaItemId,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.progressPercent,
    required this.isCompleted,
  });

  final String mediaItemId;
  final int positionSeconds;
  final int? durationSeconds;
  final double progressPercent;
  final bool isCompleted;

  factory MediaProgress.fromJson(Map<String, dynamic> json) {
    return MediaProgress(
      mediaItemId: json["media_item_id"] as String? ?? "",
      positionSeconds: json["position_seconds"] as int? ?? 0,
      durationSeconds: json["duration_seconds"] as int?,
      progressPercent: (json["progress_percent"] as num?)?.toDouble() ?? 0,
      isCompleted: json["is_completed"] as bool? ?? false,
    );
  }
}

class MediaStreamInfo {
  const MediaStreamInfo({
    required this.fileId,
    required this.mediaItemId,
    required this.streamUrl,
    required this.expiresInSec,
  });

  final String fileId;
  final String mediaItemId;
  final String streamUrl;
  final int expiresInSec;

  factory MediaStreamInfo.fromJson(Map<String, dynamic> json) {
    return MediaStreamInfo(
      fileId: json["file_id"] as String? ?? "",
      mediaItemId: json["media_item_id"] as String? ?? "",
      streamUrl: json["stream_url"] as String? ?? "",
      expiresInSec: json["expires_in_sec"] as int? ?? 0,
    );
  }
}

class MediaUploadInitInfo {
  const MediaUploadInitInfo({
    required this.fileId,
    required this.mediaItemId,
    required this.uploadUrl,
  });

  final String fileId;
  final String mediaItemId;
  final String uploadUrl;

  factory MediaUploadInitInfo.fromJson(Map<String, dynamic> json) {
    return MediaUploadInitInfo(
      fileId: json["file_id"] as String? ?? "",
      mediaItemId: json["media_item_id"] as String? ?? "",
      uploadUrl: json["upload_url"] as String? ?? "",
    );
  }
}

class LibraryRepository {
  LibraryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MediaListItem>> fetchMediaItems({
    required String accessToken,
    String? query,
    String? type,
  }) async {
    final params = <String>["limit=50", "offset=0"];
    final normalizedQuery = query?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      params.add("q=${Uri.encodeQueryComponent(normalizedQuery)}");
    }
    final normalizedType = type?.trim();
    if (normalizedType != null && normalizedType.isNotEmpty) {
      params.add("type=${Uri.encodeQueryComponent(normalizedType)}");
    }
    final response = await _apiClient.getJson(
      "/media-items?${params.join("&")}",
      accessToken: accessToken,
    );
    final items = response["items"];
    if (items is! List<dynamic>) {
      throw ApiException("Invalid library response format");
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(MediaListItem.fromJson)
        .toList(growable: false);
  }

  Future<MediaListItem> createMediaItem({
    required String accessToken,
    required String type,
    required String title,
    String? author,
  }) async {
    final body = <String, dynamic>{"type": type, "title": title};
    final normalizedAuthor = author?.trim();
    if (normalizedAuthor != null && normalizedAuthor.isNotEmpty) {
      body["author"] = normalizedAuthor;
    }
    final response = await _apiClient.postJson(
      "/media-items",
      body,
      accessToken: accessToken,
    );
    return MediaListItem.fromJson(response);
  }

  Future<List<MediaLinkItem>> fetchMediaLinks({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.getJsonList(
      "/media-items/$mediaItemId/links",
      accessToken: accessToken,
    );
    return response
        .whereType<Map<String, dynamic>>()
        .map(MediaLinkItem.fromJson)
        .toList(growable: false);
  }

  Future<MediaListItem> fetchMediaItemById({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.getJson(
      "/media-items/$mediaItemId",
      accessToken: accessToken,
    );
    return MediaListItem.fromJson(response);
  }

  Future<MediaProgress> fetchMediaProgress({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.getJson(
      "/media-items/$mediaItemId/progress",
      accessToken: accessToken,
    );
    return MediaProgress.fromJson(response);
  }

  Future<MediaProgress> upsertMediaProgress({
    required String accessToken,
    required String mediaItemId,
    required int positionSeconds,
    required int? durationSeconds,
    required bool isCompleted,
  }) async {
    final response = await _apiClient
        .putJson("/media-items/$mediaItemId/progress", <String, dynamic>{
          "position_seconds": positionSeconds,
          "duration_seconds": durationSeconds,
          "is_completed": isCompleted,
        }, accessToken: accessToken);
    return MediaProgress.fromJson(response);
  }

  Future<MediaStreamInfo> fetchMediaStreamUrl({
    required String accessToken,
    required String fileId,
  }) async {
    final response = await _apiClient.getJson(
      "/media-files/$fileId/stream",
      accessToken: accessToken,
    );
    return MediaStreamInfo.fromJson(response);
  }

  Future<MediaUploadInitInfo> initiateFileUpload({
    required String accessToken,
    required String mediaItemId,
    required String filename,
    required String contentType,
    required int fileSize,
  }) async {
    final response = await _apiClient.postJson(
      "/media-items/$mediaItemId/files/upload",
      <String, dynamic>{
        "filename": filename,
        "content_type": contentType,
        "file_size": fileSize,
      },
      accessToken: accessToken,
    );
    return MediaUploadInitInfo.fromJson(response);
  }

  Future<void> uploadBytesToPresignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final targetUri = _normalizeUploadUri(uploadUrl);
    final credential = targetUri.queryParameters["X-Amz-Credential"];
    if (credential != null && credential.startsWith("test-access-key/")) {
      throw ApiException(
        "S3 в backend не настроен: используется тестовый AWS ключ. "
        "Заполните S3_ENDPOINT_URL/AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY/S3_BUCKET в backend/.env.",
      );
    }
    http.Response response;
    try {
      response = await http
          .put(
            targetUri,
            headers: <String, String>{"Content-Type": contentType},
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw ApiException("Таймаут при загрузке файла в хранилище");
    } on Exception {
      throw ApiException(
        "Не удалось загрузить файл в хранилище. "
        "Endpoint: ${targetUri.host}. "
        "Проверьте доступность S3 endpoint (для Android эмулятора используйте 10.0.2.2 вместо localhost).",
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        "Хранилище вернуло ошибку при загрузке файла: HTTP ${response.statusCode}",
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> completeFileUpload({
    required String accessToken,
    required String fileId,
  }) async {
    await _apiClient.postJson(
      "/media-files/$fileId/complete",
      const <String, dynamic>{},
      accessToken: accessToken,
    );
  }

  Future<MediaListItem> updateMediaMetadata({
    required String accessToken,
    required String mediaItemId,
    required Map<String, dynamic> metadataJson,
  }) async {
    final response = await _apiClient.patchJson(
      "/media-items/$mediaItemId",
      <String, dynamic>{"metadata_json": metadataJson},
      accessToken: accessToken,
    );
    return MediaListItem.fromJson(response);
  }

  Uri _normalizeUploadUri(String uploadUrl) {
    final uri = Uri.parse(uploadUrl);
    if (!Platform.isAndroid) {
      return uri;
    }
    if (uri.host == "localhost" || uri.host == "127.0.0.1") {
      return uri.replace(host: "10.0.2.2");
    }
    return uri;
  }
}
