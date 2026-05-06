import "../../../core/network/api_client.dart";

class MediaListItem {
  const MediaListItem({
    required this.id,
    required this.title,
    required this.type,
    this.author,
    this.description,
  });

  final String id;
  final String title;
  final String type;
  final String? author;
  final String? description;

  factory MediaListItem.fromJson(Map<String, dynamic> json) {
    return MediaListItem(
      id: json["id"] as String? ?? "",
      title: json["title"] as String? ?? "Untitled",
      type: json["type"] as String? ?? "unknown",
      author: json["author"] as String?,
      description: json["description"] as String?,
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

  Future<void> createMediaItem({
    required String accessToken,
    required String type,
    required String title,
    String? author,
  }) async {
    final body = <String, dynamic>{
      "type": type,
      "title": title,
    };
    final normalizedAuthor = author?.trim();
    if (normalizedAuthor != null && normalizedAuthor.isNotEmpty) {
      body["author"] = normalizedAuthor;
    }
    await _apiClient.postJson("/media-items", body, accessToken: accessToken);
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
}
