/// DTO каталога и связанные модели в формате REST API (`/media-items`, файлы, прогресс, связи).
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
    this.averageRating,
    this.ratingsCount = 0,
    this.viewsCount = 0,
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

  /// Сервер: pending | approved | rejected — состояние модерации карточки.
  final String moderationStatus;

  /// Средняя оценка всех пользователей (1–5), если есть оценки.
  final double? averageRating;

  /// Сколько пользователей поставили оценку.
  final int ratingsCount;

  /// Сколько раз открывали карточку произведения.
  final int viewsCount;

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
    double? averageRating,
    int? ratingsCount,
    int? viewsCount,
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
      averageRating: averageRating ?? this.averageRating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      viewsCount: viewsCount ?? this.viewsCount,
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
      id: json["id"]?.toString() ?? "",
      userId: json["user_id"]?.toString(),
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
      averageRating: (json["average_rating"] as num?)?.toDouble(),
      ratingsCount: json["ratings_count"] as int? ?? 0,
      viewsCount: json["views_count"] as int? ?? 0,
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
      "average_rating": averageRating,
      "ratings_count": ratingsCount,
      "views_count": viewsCount,
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

class MediaComment {
  const MediaComment({
    required this.id,
    required this.mediaItemId,
    required this.userId,
    required this.authorDisplayName,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String mediaItemId;
  final String userId;
  final String authorDisplayName;
  final String text;
  final String createdAt;
  final String updatedAt;

  factory MediaComment.fromJson(Map<String, dynamic> json) {
    return MediaComment(
      id: json["id"] as String? ?? "",
      mediaItemId: json["media_item_id"] as String? ?? "",
      userId: json["user_id"] as String? ?? "",
      authorDisplayName: json["author_display_name"] as String? ?? "Пользователь",
      text: json["text"] as String? ?? "",
      createdAt: json["created_at"] as String? ?? "",
      updatedAt: json["updated_at"] as String? ?? "",
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
    this.ratingStars,
    this.updatedAtUtcMs,
  });

  final String mediaItemId;
  final int positionSeconds;
  final int? durationSeconds;
  final double progressPercent;
  final bool isCompleted;

  /// Личная оценка 1–5 с сервера (`GET …/progress`, `PUT …/rating`).
  final int? ratingStars;

  /// Из ответа `GET/PUT …/progress` (`updated_at` в RFC3339).
  final int? updatedAtUtcMs;

  static double computeProgressPercent(
    int positionSeconds,
    int? durationSeconds,
  ) {
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
      ratingStars: _parseRatingStars(json["rating_stars"]),
      updatedAtUtcMs: decodeUpdatedAtUtcMs(json["updated_at"]),
    );
  }

  factory MediaProgress.synthesized({
    required String mediaItemId,
    required int positionSeconds,
    required int? durationSeconds,
    required bool isCompleted,
    int? ratingStars,
  }) {
    return MediaProgress(
      mediaItemId: mediaItemId,
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds,
      progressPercent: computeProgressPercent(positionSeconds, durationSeconds),
      isCompleted: isCompleted,
      ratingStars: ratingStars,
      updatedAtUtcMs: null,
    );
  }

  static int? _parseRatingStars(dynamic raw) {
    if (raw is int) {
      if (raw >= 1 && raw <= 5) {
        return raw;
      }
      return null;
    }
    if (raw is num) {
      final v = raw.round();
      if (v >= 1 && v <= 5) {
        return v;
      }
    }
    return null;
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
  const MediaItemsFetchResult({required this.items, required this.total});

  final List<MediaListItem> items;
  final int total;
}

/// Нормализованное имя автора для сравнения и фильтрации.
String normalizeAuthorKey(String? author) => (author ?? "").trim().toLowerCase();

/// Ключ одного произведения: один заголовок и автор, разные форматы — одна работа.
String mediaWorkGroupKey(MediaListItem item) {
  return "${item.title.trim().toLowerCase()}::${normalizeAuthorKey(item.author)}";
}
