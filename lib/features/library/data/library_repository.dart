import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:http/http.dart" as http;

import "../../../core/config/app_config.dart";
import "../../../core/network/api_client.dart";

class MediaListItem {
  const MediaListItem({
    required this.id,
    this.userId,
    required this.title,
    required this.type,
    this.author,
    this.coverUrl,
    this.genres,
    this.description,
    this.metadataJson,
    this.moderationStatus = 'approved',
  });

  final String id;
  final String? userId;
  final String title;
  final String type;
  final String? author;
  final String? coverUrl;
  final List<String>? genres;
  final String? description;
  final Map<String, dynamic>? metadataJson;
  /// Server: pending | approved | rejected
  final String moderationStatus;

  MediaListItem copyWith({
    String? userId,
    String? title,
    String? type,
    String? author,
    String? coverUrl,
    List<String>? genres,
    String? description,
    Map<String, dynamic>? metadataJson,
    String? moderationStatus,
  }) {
    return MediaListItem(
      id: id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      genres: genres ?? this.genres,
      description: description ?? this.description,
      metadataJson: metadataJson ?? this.metadataJson,
      moderationStatus: moderationStatus ?? this.moderationStatus,
    );
  }

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

  String? get coverFileId {
    final metadata = metadataJson;
    if (metadata == null) {
      return null;
    }
    final direct = metadata["cover_file_id"];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
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
      userId: json["user_id"] as String?,
      title: json["title"] as String? ?? "Untitled",
      type: json["type"] as String? ?? "unknown",
      author: json["author"] as String?,
      coverUrl: json["cover_url"] as String?,
      genres: (json["genres"] as List<dynamic>?)
          ?.whereType<String>()
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toList(growable: false),
      description: json["description"] as String?,
      metadataJson: metadata,
      moderationStatus: json["moderation_status"] as String? ?? "approved",
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "user_id": userId,
      "title": title,
      "type": type,
      "author": author,
      "cover_url": coverUrl,
      "genres": genres,
      "description": description,
      "metadata_json": metadataJson,
      "moderation_status": moderationStatus,
    };
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
    this.updatedAtUtcMs,
  });

  final String mediaItemId;
  final int positionSeconds;
  final int? durationSeconds;
  final double progressPercent;
  final bool isCompleted;

  /// Из ответа `GET/PUT …/progress` (`updated_at` в RFC3339).
  final int? updatedAtUtcMs;

  static double computeProgressPercent(int positionSeconds, int? durationSeconds) {
    if (durationSeconds == null || durationSeconds <= 0) {
      return 0.0;
    }
    var percent = (positionSeconds / durationSeconds) * 100;
    percent = percent < 0 ? 0 : (percent > 100 ? 100 : percent);
    return (percent * 100).roundToDouble() / 100;
  }

  factory MediaProgress.fromJson(Map<String, dynamic> json) {
    final pos = json["position_seconds"] as int? ?? 0;
    final dur = json["duration_seconds"] as int?;
    final pct = (json["progress_percent"] as num?)?.toDouble();
    final completed = json["is_completed"] as bool? ?? false;
    return MediaProgress(
      mediaItemId: json["media_item_id"] as String? ?? "",
      positionSeconds: pos,
      durationSeconds: dur,
      progressPercent: pct ?? computeProgressPercent(pos, dur),
      isCompleted: completed,
      updatedAtUtcMs: decodeUpdatedAtUtcMs(json["updated_at"]),
    );
  }

  factory MediaProgress.synthesized({
    required String mediaItemId,
    required int positionSeconds,
    required int? durationSeconds,
    required bool isCompleted,
  }) {
    return MediaProgress(
      mediaItemId: mediaItemId,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      progressPercent: computeProgressPercent(positionSeconds, durationSeconds),
      isCompleted: isCompleted,
      updatedAtUtcMs: null,
    );
  }

  static int? decodeUpdatedAtUtcMs(dynamic raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc().millisecondsSinceEpoch;
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

class MediaFileSummary {
  const MediaFileSummary({
    required this.id,
    required this.contentType,
    required this.uploadStatus,
    this.fileSize,
    this.uploadedAt,
    required this.createdAt,
  });

  final String id;
  final String contentType;
  final String uploadStatus;
  final int? fileSize;
  final String? uploadedAt;
  final String createdAt;

  factory MediaFileSummary.fromJson(Map<String, dynamic> json) {
    return MediaFileSummary(
      id: json["id"] as String? ?? "",
      contentType: json["content_type"] as String? ?? "",
      uploadStatus: json["upload_status"] as String? ?? "",
      fileSize: json["file_size"] as int?,
      uploadedAt: json["uploaded_at"] as String?,
      createdAt: json["created_at"] as String? ?? "",
    );
  }
}

class MediaItemsFetchResult {
  const MediaItemsFetchResult({
    required this.items,
    required this.total,
  });

  final List<MediaListItem> items;
  final int total;
}

class LibraryRepository {
  LibraryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MediaListItem>> fetchMediaItems({
    required String accessToken,
    String? query,
    String? type,
    List<String> types = const [],
    List<String> genres = const [],
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await fetchMediaItemsWithMeta(
      accessToken: accessToken,
      query: query,
      type: type,
      types: types,
      genres: genres,
      moderationStatus: null,
      limit: limit,
      offset: offset,
    );
    return r.items;
  }

  Future<MediaItemsFetchResult> fetchMediaItemsWithMeta({
    required String accessToken,
    String? query,
    String? type,
    List<String> types = const [],
    List<String> genres = const [],
    String? moderationStatus,
    bool excludePending = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String>["limit=$limit", "offset=$offset"];
    final normalizedQuery = query?.trim();
    if (normalizedQuery != null && normalizedQuery.isNotEmpty) {
      params.add("q=${Uri.encodeQueryComponent(normalizedQuery)}");
    }
    for (final t in _normalizeQueryTypes(types, type)) {
      params.add("types=${Uri.encodeQueryComponent(t)}");
    }
    for (final g in _normalizeGenresForQuery(genres)) {
      params.add("genres=${Uri.encodeQueryComponent(g)}");
    }
    final mod = moderationStatus?.trim();
    if (mod != null && mod.isNotEmpty) {
      params.add("moderation_status=${Uri.encodeQueryComponent(mod)}");
    }
    if (excludePending) {
      params.add("exclude_pending=true");
    }
    final response = await _apiClient.getJson(
      "/media-items?${params.join("&")}",
      accessToken: accessToken,
    );
    final items = response["items"];
    if (items is! List<dynamic>) {
      throw ApiException("Invalid library response format");
    }
    final list =
        items
            .whereType<Map<String, dynamic>>()
            .where((row) => row["deleted_at"] == null)
            .map(MediaListItem.fromJson)
            .toList(growable: false);
    final rawTotal = response["total"];
    final total = rawTotal is int ? rawTotal : int.tryParse("$rawTotal") ?? 0;
    return MediaItemsFetchResult(items: list, total: total);
  }

  Future<List<String>> fetchAvailableGenres({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      "/media-genres",
      accessToken: accessToken,
    );
    final genres = response["genres"];
    if (genres is! List<dynamic>) {
      return const [];
    }
    return genres
        .whereType<String>()
        .map((genre) => genre.trim())
        .where((genre) => genre.isNotEmpty)
        .toList(growable: false);
  }

  Future<MediaListItem> createMediaItem({
    required String accessToken,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
  }) async {
    final body = <String, dynamic>{"type": type, "title": title};
    final normalizedAuthor = author?.trim();
    if (normalizedAuthor != null && normalizedAuthor.isNotEmpty) {
      body["author"] = normalizedAuthor;
    }
    final normalizedCoverUrl = coverUrl?.trim();
    if (normalizedCoverUrl != null && normalizedCoverUrl.isNotEmpty) {
      body["cover_url"] = normalizedCoverUrl;
    }
    if (genres != null) {
      final normalizedGenres = genres
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toList(growable: false);
      if (normalizedGenres.isNotEmpty) {
        body["genres"] = normalizedGenres;
      }
    }
    final response = await _apiClient.postJson(
      "/media-items",
      body,
      accessToken: accessToken,
    );
    return MediaListItem.fromJson(response);
  }

  Future<MediaListItem> updateMediaItem({
    required String accessToken,
    required String mediaItemId,
    String? title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    String? description,
    Map<String, dynamic>? metadataJson,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) {
      body["title"] = title.trim();
    }
    if (author != null) {
      body["author"] = author.trim().isEmpty ? null : author.trim();
    }
    if (coverUrl != null) {
      body["cover_url"] = coverUrl.trim().isEmpty ? null : coverUrl.trim();
    }
    if (genres != null) {
      body["genres"] = genres
          .map((genre) => genre.trim())
          .where((genre) => genre.isNotEmpty)
          .toList(growable: false);
    }
    if (description != null) {
      body["description"] =
          description.trim().isEmpty ? null : description.trim();
    }
    if (metadataJson != null) {
      body["metadata_json"] = metadataJson;
    }
    final response = await _apiClient.patchJson(
      "/media-items/$mediaItemId",
      body,
      accessToken: accessToken,
    );
    return MediaListItem.fromJson(response);
  }

  Future<void> deleteMediaItem({
    required String accessToken,
    required String mediaItemId,
  }) async {
    await _apiClient.deleteJson(
      "/media-items/$mediaItemId",
      accessToken: accessToken,
    );
  }

  Future<MediaListItem> approveMediaModeration({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.postJson(
      "/admin/media-items/$mediaItemId/approve",
      const <String, dynamic>{},
      accessToken: accessToken,
    );
    return MediaListItem.fromJson(response);
  }

  Future<MediaListItem> rejectMediaModeration({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.postJson(
      "/admin/media-items/$mediaItemId/reject",
      const <String, dynamic>{},
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

  Future<MediaLinkItem> createMediaLink({
    required String accessToken,
    required String sourceMediaId,
    required String targetMediaId,
    String relationType = "related",
  }) async {
    final response = await _apiClient
        .postJson("/media-links", <String, dynamic>{
          "source_media_id": sourceMediaId,
          "target_media_id": targetMediaId,
          "relation_type": relationType,
        }, accessToken: accessToken);
    return MediaLinkItem.fromJson(response);
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
    final streamInfo = MediaStreamInfo.fromJson(response);
    final normalizedStreamUrl =
        _normalizeStreamUri(streamInfo.streamUrl).toString();
    return MediaStreamInfo(
      fileId: streamInfo.fileId,
      mediaItemId: streamInfo.mediaItemId,
      streamUrl: normalizedStreamUrl,
      expiresInSec: streamInfo.expiresInSec,
    );
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

  Future<List<MediaFileSummary>> fetchMediaFilesForItem({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final raw = await _apiClient.getJsonList(
      "/media-items/$mediaItemId/files",
      accessToken: accessToken,
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(MediaFileSummary.fromJson)
        .toList(growable: false);
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

  /// Подмена localhost → 10.0.2.2 нужна только при API с хоста эмулятора.
  /// На физическом устройстве с облаком presigned URL не трогаем — иначе запросы
  /// уходят на 10.0.2.2 на самом телефоне и плеер не готовится.
  bool get _shouldRewriteLocalS3HostsForAndroidEmulator {
    if (!Platform.isAndroid) {
      return false;
    }
    final base = AppConfig.apiBaseUrl.trim().toLowerCase();
    return base.contains("10.0.2.2") ||
        base.contains("127.0.0.1") ||
        base.contains("localhost");
  }

  Uri _normalizeUploadUri(String uploadUrl) {
    final uri = Uri.parse(uploadUrl);
    if (!_shouldRewriteLocalS3HostsForAndroidEmulator) {
      return uri;
    }
    if (uri.host == "localhost" ||
        uri.host == "127.0.0.1" ||
        uri.host == "minio" ||
        uri.host == "host.docker.internal") {
      return uri.replace(host: "10.0.2.2");
    }
    if (uri.host.endsWith(".localhost")) {
      final bucket = uri.host.substring(
        0,
        uri.host.length - ".localhost".length,
      );
      return uri.replace(host: "10.0.2.2", path: "/$bucket${uri.path}");
    }
    if (uri.host.endsWith(".127.0.0.1")) {
      final bucket = uri.host.substring(
        0,
        uri.host.length - ".127.0.0.1".length,
      );
      return uri.replace(host: "10.0.2.2", path: "/$bucket${uri.path}");
    }
    return uri;
  }

  Uri _normalizeStreamUri(String streamUrl) {
    final uri = Uri.parse(streamUrl);
    if (!_shouldRewriteLocalS3HostsForAndroidEmulator) {
      return uri;
    }
    if (uri.host == "localhost" ||
        uri.host == "127.0.0.1" ||
        uri.host == "minio" ||
        uri.host == "host.docker.internal") {
      return uri.replace(host: "10.0.2.2");
    }
    if (uri.host.endsWith(".localhost")) {
      final bucket = uri.host.substring(
        0,
        uri.host.length - ".localhost".length,
      );
      return uri.replace(host: "10.0.2.2", path: "/$bucket${uri.path}");
    }
    if (uri.host.endsWith(".127.0.0.1")) {
      final bucket = uri.host.substring(
        0,
        uri.host.length - ".127.0.0.1".length,
      );
      return uri.replace(host: "10.0.2.2", path: "/$bucket${uri.path}");
    }
    return uri;
  }
}

List<String> _normalizeQueryTypes(List<String> types, String? legacyType) {
  const allowed = {'book', 'audiobook', 'video'};
  final out = <String>[];
  final seen = <String>{};
  for (final raw in types) {
    final t = raw.trim().toLowerCase();
    if (!allowed.contains(t) || seen.contains(t)) {
      continue;
    }
    seen.add(t);
    out.add(t);
  }
  if (out.isEmpty) {
    final lt = legacyType?.trim().toLowerCase();
    if (lt != null && lt.isNotEmpty && allowed.contains(lt)) {
      out.add(lt);
    }
  }
  return out;
}

List<String> _normalizeGenresForQuery(List<String> genres) {
  final out = <String>[];
  final seen = <String>{};
  for (final raw in genres) {
    final g = raw.trim();
    if (g.isEmpty) {
      continue;
    }
    final key = g.toLowerCase();
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    out.add(g);
    if (out.length >= 24) {
      break;
    }
  }
  return out;
}
