part of 'library_screen.dart';

// Вспомогательные штуки для библиотеки: как показать тип контента словами, как открыть карточку произведения,
// как собрать одну «работу» из нескольких форматов (книга + аудио), маленькие функции про картинки и жанры.

/// Как показать пользователю тип контента обычным словом («Книга», а не внутренний код).
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

/// Убираем повторы жанра в разном написании — оставляем один раз, без учёта заглавных букв.
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

/// По имени файла картинки угадываем формат (jpeg, png и т.д.) — нужно при загрузке обложки.
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

/// Открывает большой экран одного произведения и передаёт туда все нужные «что сделать по нажатию» из родителя.
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

/// То же открытие карточки, но проще вызвать из приложения: внутри подставляются готовые действия из общего состояния.
Future<void> openMediaItemDetailsForAppState({
  required BuildContext context,
  required AppState state,
  required List<MediaListItem> groupItems,
}) {
  return openMediaItemDetailsPage(
    context: context,
    currentUserId: state.currentUserId,
    groupItems: groupItems,
    availableGenres: state.availableGenres,
    onLoadLinks: state.fetchLinksForItem,
    onLoadItemById: state.fetchMediaItemById,
    onUpdateItem:
        ({
          required mediaItemId,
          required type,
          required title,
          author,
          coverUrl,
          genres,
          coverUploadPayload,
          uploadPayload,
          description,
        }) => state.updateMediaItem(
          mediaItemId: mediaItemId,
          type: type,
          title: title,
          author: author,
          coverUrl: coverUrl,
          genres: genres,
          coverUploadPayload: coverUploadPayload,
          uploadPayload: uploadPayload,
          description: description,
        ),
    onAddFormatToWork:
        ({
          required sourceMediaItemId,
          required type,
          required title,
          author,
          coverUrl,
          genres,
          coverUploadPayload,
          description,
          uploadPayload,
        }) => state.addFormatToWork(
          sourceMediaItemId: sourceMediaItemId,
          type: type,
          title: title,
          author: author,
          coverUrl: coverUrl,
          genres: genres,
          coverUploadPayload: coverUploadPayload,
          description: description,
          uploadPayload: uploadPayload,
        ),
    onBeginPlaybackSession: state.beginPlaybackSession,
    onPlaybackProgressChanged: state.updatePlaybackProgress,
    onPausePlaybackSession: state.pausePlaybackSession,
    onCompletePlaybackSession: state.completePlaybackSession,
    onFlushPlaybackSession: state.flushPlaybackProgress,
    onEndPlaybackSession: state.endPlaybackSession,
    playbackSpeed: state.playbackSpeed,
    onSetPlaybackSpeed: state.setPlaybackSpeed,
    pendingPlaybackSync: state.pendingPlaybackSync,
    onFetchPlaybackStreamUrl: state.fetchPlaybackStreamUrl,
    playbackError: state.playbackError,
    onLoadBookContent: state.loadBookContent,
    onMarkItemViewed: state.markItemViewed,
    onFetchMediaFiles: state.fetchMediaFilesForItem,
    onBindMainMediaFile: state.bindMainMediaFileToItem,
    onUploadAndBindMainMediaFile: state.uploadAndBindMainMediaFile,
  );
}

/// Одно произведение для сетки: под одним названием и автором может быть книга, аудио и видео — здесь они собраны вместе.
class _WorkGroup {
  _WorkGroup({required this.groupItems});

  final List<MediaListItem> groupItems;

  MediaListItem get primaryItem => groupItems.first;
  String get displayTitle => primaryItem.title;
  String get displayAuthor => primaryItem.author ?? "";
  List<String> get types =>
      groupItems.map((item) => item.type).toSet().toList(growable: false)
        ..sort();

  /// Плашка на обложке: «на проверке» или «отклонено», если среди ваших вариантов есть такие статусы.
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
