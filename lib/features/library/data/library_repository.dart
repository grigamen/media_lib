import "../../../core/network/api_client.dart";

class MediaListItem {
  MediaListItem({
    required this.id,
    required this.title,
    required this.type,
    this.author,
  });

  final String id;
  final String title;
  final String type;
  final String? author;

  factory MediaListItem.fromJson(Map<String, dynamic> json) {
    return MediaListItem(
      id: json["id"] as String? ?? "",
      title: json["title"] as String? ?? "Untitled",
      type: json["type"] as String? ?? "unknown",
      author: json["author"] as String?,
    );
  }
}

class LibraryRepository {
  LibraryRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MediaListItem>> fetchMediaItems({required String accessToken}) async {
    final response = await _apiClient.getJson("/media-items?limit=50&offset=0", accessToken: accessToken);
    final items = response["items"];
    if (items is! List<dynamic>) {
      throw ApiException("Invalid library response format");
    }
    return items
        .whereType<Map<String, dynamic>>()
        .map(MediaListItem.fromJson)
        .toList(growable: false);
  }
}
