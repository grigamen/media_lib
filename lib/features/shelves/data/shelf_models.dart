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
    this.coverMediaItemId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int itemCount;
  final String? coverUrl;
  final String? coverMediaItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserShelfSummary copyWith({
    String? name,
    int? itemCount,
    String? coverUrl,
    String? coverMediaItemId,
    DateTime? updatedAt,
  }) {
    return UserShelfSummary(
      id: id,
      name: name ?? this.name,
      itemCount: itemCount ?? this.itemCount,
      coverUrl: coverUrl ?? this.coverUrl,
      coverMediaItemId: coverMediaItemId ?? this.coverMediaItemId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserShelfSummary.fromJson(Map<String, dynamic> json) {
    final rawItems = json["items"];
    final itemsLen = rawItems is List ? rawItems.length : 0;
    final itemCount = _readInt(json["item_count"]);
    final cover = json["cover_url"] as String?;
    final coverItemId = json["cover_media_item_id"];
    return UserShelfSummary(
      id: json["id"]?.toString() ?? "",
      name: json["name"] as String? ?? "",
      itemCount: itemCount > 0 ? itemCount : itemsLen,
      coverUrl: cover != null && cover.trim().isNotEmpty ? cover.trim() : null,
      coverMediaItemId: coverItemId != null ? coverItemId.toString() : null,
      createdAt: _readDateTime(json["created_at"]),
      updatedAt: _readDateTime(json["updated_at"]),
    );
  }
}

/// Первая книга на полке с обложкой; иначе любой элемент с обложкой.
MediaListItem? pickShelfCoverItem(Iterable<MediaListItem> items) {
  final ordered = items.toList(growable: false);
  for (final bookOnly in [true, false]) {
    for (var i = ordered.length - 1; i >= 0; i--) {
      final item = ordered[i];
      if (bookOnly && item.type != "book") {
        continue;
      }
      final hasCover =
          (item.coverUrl?.trim().isNotEmpty ?? false) ||
          (item.coverFileId?.trim().isNotEmpty ?? false);
      if (hasCover) {
        return item;
      }
    }
  }
  return null;
}

MediaListItem? _catalogItemById(
  List<MediaListItem> catalogItems,
  String itemId,
) {
  final normalized = itemId.toLowerCase();
  for (final item in catalogItems) {
    if (item.id == itemId || item.id.toLowerCase() == normalized) {
      return item;
    }
  }
  return null;
}

/// Обложка полки: presigned URL с каталога или сохранённый URL.
String? shelfCoverUrlForShelf(
  UserShelfSummary shelf,
  List<MediaListItem> catalogItems,
) {
  final itemId = shelf.coverMediaItemId;
  if (itemId != null && itemId.isNotEmpty) {
    final item = _catalogItemById(catalogItems, itemId);
    final fromCatalog = item?.coverUrl?.trim();
    if (fromCatalog != null && fromCatalog.isNotEmpty) {
      return fromCatalog;
    }
  }
  final direct = shelf.coverUrl?.trim();
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }
  return null;
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
      items: rawItems
          .map((e) => MediaListItem.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      createdAt: _readDateTime(json["created_at"]),
      updatedAt: _readDateTime(json["updated_at"]),
    );
  }
}
