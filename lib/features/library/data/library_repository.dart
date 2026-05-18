import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:http/http.dart" as http;

import "../../../core/config/app_config.dart";
import "../../../core/network/api_client.dart";

import "library_models.dart";

export "library_models.dart";

part "library_repository_presigned.dart";

/// Обращения к REST API каталога: списки, CRUD, прогресс, стримы и метаданные.
/// Загрузка файлов по presigned URL — в [library_repository_presigned.dart].
class LibraryRepository {
  LibraryRepository(this._apiClient);

  final ApiClient _apiClient;

  /// Список произведений (обёртка над [fetchMediaItemsWithMeta] без total).
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

  /// Пагинированная выборка с query-параметрами и полем [total] от сервера.
  Future<MediaItemsFetchResult> fetchMediaItemsWithMeta({
    required String accessToken,
    String? query,
    String? type,
    List<String> types = const [],
    List<String> genres = const [],
    String? moderationStatus,
    bool excludePending = false,
    bool mine = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String>["limit=$limit", "offset=$offset"];
    if (mine) {
      params.add("mine=true");
    }
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
    final list = items
        .whereType<Map<String, dynamic>>()
        .where((row) => row["deleted_at"] == null)
        .map(MediaListItem.fromJson)
        .toList(growable: false);
    final rawTotal = response["total"];
    final total = rawTotal is int ? rawTotal : int.tryParse("$rawTotal") ?? 0;
    return MediaItemsFetchResult(items: list, total: total);
  }

  /// Справочник жанров с backend (`GET /media-genres`).
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

  /// Создание произведения (черновик с модерацией).
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

  /// Частичное обновление полей карточки (PATCH).
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

  /// Soft-delete произведения для текущего владельца (или админа по правилам API).
  Future<void> deleteMediaItem({
    required String accessToken,
    required String mediaItemId,
  }) async {
    await _apiClient.deleteJson(
      "/media-items/$mediaItemId",
      accessToken: accessToken,
    );
  }

  /// Админ: одобрить модерацию.
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

  /// Админ: отклонить модерацию.
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

  /// Связи между произведениями (форматы одной работы и т.д.).
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

  /// Создать связь source → target с типом отношения.
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

  /// Одна карточка по id (при отсутствии прав API вернёт 404).
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

  /// Текущий прогресс слушателя/читателя по произведению.
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

  /// Сохранить позицию и длительность воспроизведения (UPSERT на сервере).
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

  /// Личная оценка 1–5 звёзд (хранится в строке прогресса на сервере).
  Future<MediaProgress> setMediaItemRating({
    required String accessToken,
    required String mediaItemId,
    required int stars,
  }) async {
    final response = await _apiClient.putJson(
      "/media-items/$mediaItemId/rating",
      <String, dynamic>{"stars": stars},
      accessToken: accessToken,
    );
    return MediaProgress.fromJson(response);
  }

  /// Зафиксировать просмотр карточки (+1 к views_count на сервере).
  Future<MediaListItem> recordMediaItemView({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.postJson(
      "/media-items/$mediaItemId/view",
      const <String, dynamic>{},
      accessToken: accessToken,
    );
    return MediaListItem.fromJson(response);
  }

  /// Снять личную оценку (звёзды), позицию просмотра не меняет.
  Future<MediaProgress> clearMediaItemRating({
    required String accessToken,
    required String mediaItemId,
  }) async {
    final response = await _apiClient.deleteJson(
      "/media-items/$mediaItemId/rating",
      accessToken: accessToken,
    );
    return MediaProgress.fromJson(response);
  }

  /// Presigned GET для воспроизведения; при dev — подмена хоста для Android-эмулятора.
  Future<MediaStreamInfo> fetchMediaStreamUrl({
    required String accessToken,
    required String fileId,
  }) async {
    final response = await _apiClient.getJson(
      "/media-files/$fileId/stream",
      accessToken: accessToken,
    );
    final streamInfo = MediaStreamInfo.fromJson(response);
    final normalizedUri = _normalizeStreamUri(streamInfo.streamUrl);
    if (!_isLocalDevApiBase &&
        _streamHostIsUnreachableFromMobileClients(normalizedUri.host)) {
      throw ApiException(
        "Сервер отдал ссылку на хранилище (${normalizedUri.host}) — с телефона до неё не достучаться. "
        "Укажите в backend переменную S3_PUBLIC_ENDPOINT_URL (публичный URL MinIO/S3, как для браузера) "
        "и перезапустите API.",
      );
    }
    return MediaStreamInfo(
      fileId: streamInfo.fileId,
      mediaItemId: streamInfo.mediaItemId,
      streamUrl: normalizedUri.toString(),
      expiresInSec: streamInfo.expiresInSec,
    );
  }

  /// Список медиафайлов, привязанных к произведению.
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

  /// Обновить только `metadata_json` (например `media_file_id` после загрузки).
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
    return _isLocalDevApiBase;
  }

  /// API ходит на машину разработчика (эмулятор / симулятор), а не на облако или LAN-only сервер.
  bool get _isLocalDevApiBase {
    final base = AppConfig.apiBaseUrl.trim().toLowerCase();
    return base.contains("10.0.2.2") ||
        base.contains("127.0.0.1") ||
        base.contains("localhost");
  }

  /// Хост presigned URL недоступен с мобильного без публичного endpoint (localhost и т.п.).
  bool _streamHostIsUnreachableFromMobileClients(String host) {
    final h = host.toLowerCase();
    if (h == "localhost" ||
        h == "127.0.0.1" ||
        h == "0.0.0.0" ||
        h == "minio" ||
        h == "host.docker.internal") {
      return true;
    }
    if (h.endsWith(".localhost") || h.endsWith(".127.0.0.1")) {
      return true;
    }
    return false;
  }

  /// Подстраивает presigned PUT под эмулятор (localhost → 10.0.2.2).
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

  /// Подстраивает presigned GET стрима под эмулятор.
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

/// Нормализация `types` и совместимость со старым одиночным `type` в query.
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

/// Жанры для query: уникальность без учёта регистра, лимит 24.
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
