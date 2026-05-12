part of 'library_screen.dart';

String _labelForType(String type) {
  switch (type) {
    case "book":
      return "Книга";
    case "audiobook":
      return "Аудиокнига";
    case "video":
      return "Видео";
    default:
      return type;
  }
}

List<String> _uniqueGenres(Iterable<String> genres) {
  final result = <String>[];
  final seen = <String>{};
  for (final raw in genres) {
    final genre = raw.trim();
    if (genre.isEmpty) {
      continue;
    }
    final key = genre.toLowerCase();
    if (seen.contains(key)) {
      continue;
    }
    seen.add(key);
    result.add(genre);
  }
  return result;
}

String? _inferImageMimeFromFilename(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith(".jpg") || lower.endsWith(".jpeg")) {
    return "image/jpeg";
  }
  if (lower.endsWith(".png")) {
    return "image/png";
  }
  if (lower.endsWith(".webp")) {
    return "image/webp";
  }
  return null;
}

Future<void> openMediaItemDetailsPage({
  required BuildContext context,
  required String? currentUserId,
  required List<MediaListItem> groupItems,
  required List<String> availableGenres,
  required Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks,
  required Future<MediaListItem?> Function(String mediaItemId) onLoadItemById,
  required Future<MediaListItem> Function({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  })
  onUpdateItem,
  required Future<MediaListItem> Function({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  })
  onAddFormatToWork,
  required Future<PlaybackSessionOutcome> Function(MediaListItem item)
  onBeginPlaybackSession,
  required void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged,
  required Future<void> Function() onPausePlaybackSession,
  required Future<void> Function() onCompletePlaybackSession,
  required Future<void> Function() onFlushPlaybackSession,
  required void Function() onEndPlaybackSession,
  required double playbackSpeed,
  required void Function(double) onSetPlaybackSpeed,
  required bool pendingPlaybackSync,
  required Future<String?> Function(String fileId) onFetchPlaybackStreamUrl,
  required String? playbackError,
  required Future<String> Function(MediaListItem item) onLoadBookContent,
  required void Function(String mediaItemId) onMarkItemViewed,
  required Future<List<MediaFileSummary>> Function(String mediaItemId)
  onFetchMediaFiles,
  required Future<void> Function({
    required String mediaItemId,
    required String fileId,
  })
  onBindMainMediaFile,
  required Future<void> Function({
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  })
  onUploadAndBindMainMediaFile,
}) {
  if (groupItems.isNotEmpty) {
    onMarkItemViewed(groupItems.first.id);
  }
  final group = _WorkGroup(groupItems: groupItems);
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder:
          (_) => _MediaItemDetailsPage(
            currentUserId: currentUserId,
            group: group,
            availableGenres: availableGenres,
            onLoadLinks: onLoadLinks,
            onLoadItemById: onLoadItemById,
            onUpdateItem: onUpdateItem,
            onAddFormatToWork: onAddFormatToWork,
            onBeginPlaybackSession: onBeginPlaybackSession,
            onPlaybackProgressChanged: onPlaybackProgressChanged,
            onPausePlaybackSession: onPausePlaybackSession,
            onCompletePlaybackSession: onCompletePlaybackSession,
            onFlushPlaybackSession: onFlushPlaybackSession,
            onEndPlaybackSession: onEndPlaybackSession,
            playbackSpeed: playbackSpeed,
            onSetPlaybackSpeed: onSetPlaybackSpeed,
            pendingPlaybackSync: pendingPlaybackSync,
            onFetchPlaybackStreamUrl: onFetchPlaybackStreamUrl,
            playbackError: playbackError,
            onLoadBookContent: onLoadBookContent,
            onFetchMediaFiles: onFetchMediaFiles,
            onBindMainMediaFile: onBindMainMediaFile,
            onUploadAndBindMainMediaFile: onUploadAndBindMainMediaFile,
          ),
    ),
  );
}

class _WorkGroup {
  _WorkGroup({required this.groupItems});

  final List<MediaListItem> groupItems;

  MediaListItem get primaryItem => groupItems.first;
  String get displayTitle => primaryItem.title;
  String get displayAuthor => primaryItem.author ?? "";
  List<String> get types =>
      groupItems.map((item) => item.type).toSet().toList(growable: false)
        ..sort();

  String? ownerModerationLabel(String? currentUserId) {
    if (currentUserId == null) {
      return null;
    }
    final owned =
        groupItems.where((i) => i.userId == currentUserId).toList();
    if (owned.isEmpty) {
      return null;
    }
    if (owned.any((i) => i.moderationStatus == "rejected")) {
      return "Отклонено";
    }
    if (owned.any((i) => i.moderationStatus == "pending")) {
      return "На модерации";
    }
    return null;
  }
}
