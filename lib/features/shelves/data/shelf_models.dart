import "../../library/data/library_models.dart";

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

DateTime _readDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value);
  }
  return DateTime.now().toUtc();
}

class UserShelfSummary {
  const UserShelfSummary({
    required this.id,
    required this.name,
    required this.itemCount,
    this.coverUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int itemCount;
  final String? coverUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserShelfSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json["items"];
    final itemsLen = rawItems is List ? rawItems.length : 0;
    final itemCount = _readInt(json["item_count"]);
    final cover = json["cover_url"] as String?;
    return UserShelfSummary(
      id: json["id"]?.toString() ?? "",
      name: json["name"] as String? ?? "",
      itemCount: itemCount > 0 ? itemCount : itemsLen,
      coverUrl: cover != null && cover.trim().isNotEmpty ? cover.trim() : null,
      createdAt: _readDateTime(json["created_at"]),
      updatedAt: _readDateTime(json["updated_at"]),
    );
  }
}

class UserShelfDetail {
  const UserShelfDetail({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<MediaListItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserShelfDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json["items"] as List<dynamic>? ?? const [];
    return UserShelfDetail(
      id: json["id"]?.toString() ?? "",
      name: json["name"] as String? ?? "",
      items:
          rawItems
              .map((e) => MediaListItem.fromJson(e as Map<String, dynamic>))
              .toList(growable: false),
      createdAt: _readDateTime(json["created_at"]),
      updatedAt: _readDateTime(json["updated_at"]),
    );
  }
}
