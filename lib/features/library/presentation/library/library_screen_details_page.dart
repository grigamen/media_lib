part of 'library_screen.dart';

// Описание виджета полноэкранной карточки: сюда передаётся много функций «сделать на сервере», чтобы экран ничего не знал о сети сам.

/// Большой экран одного произведения; как он живёт внутри — см. класс состояния в другом файле.
class _MediaItemDetailsPage extends StatefulWidget {
  const _MediaItemDetailsPage({
    required this.currentUserId,
    required this.isAdminUser,
    required this.group,
    this.initialMediaItemId,
    required this.availableGenres,
    required this.onLoadLinks,
    required this.onLoadItemById,
    required this.onUpdateItem,
    required this.onAddFormatToWork,
    required this.onBeginPlaybackSession,
    required this.onPlaybackProgressChanged,
    required this.onPausePlaybackSession,
    required this.onCompletePlaybackSession,
    required this.onFlushPlaybackSession,
    required this.onEndPlaybackSession,
    required this.playbackSpeed,
    required this.onSetPlaybackSpeed,
    required this.pendingPlaybackSync,
    required this.onFetchPlaybackStreamUrl,
    required this.playbackError,
    required this.onLoadBookContent,
    required this.onRecordMediaItemView,
    required this.onFetchMediaFiles,
    required this.onBindMainMediaFile,
    required this.onUploadAndBindMainMediaFile,
    required this.onFetchMediaProgress,
    required this.onSetMediaItemUserRating,
    required this.onClearMediaItemUserRating,
    required this.onFetchWorkUserRating,
    required this.onSetWorkUserRating,
    required this.onClearWorkUserRating,
    required this.onFetchMediaComments,
    required this.onCreateMediaComment,
    required this.onUpdateMediaComment,
    required this.onDeleteMediaComment,
    required this.onReportMediaComment,
    required this.onFetchItemsByAuthor,
    required this.onSearchAuthors,
    required this.onCreateAuthor,
    required this.onAddToShelf,
    this.onHasBookOfflineCopy,
    this.onDownloadBookForOffline,
    this.onSaveAuthorBookLocalFile,
  });

  final String? currentUserId;
  final bool isAdminUser;
  final _WorkGroup group;
  final String? initialMediaItemId;
  final List<String> availableGenres;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;
  final Future<MediaListItem> Function({
    required String mediaItemId,
    required String type,
    required String title,
    String? author,
    String? authorId,
    bool? clearAuthor,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    MediaUploadPayload? uploadPayload,
    String? description,
  })
  onUpdateItem;
  final Future<MediaListItem> Function({
    required String sourceMediaItemId,
    required String type,
    required String title,
    String? author,
    String? authorId,
    String? coverUrl,
    List<String>? genres,
    MediaUploadPayload? coverUploadPayload,
    String? description,
    MediaUploadPayload? uploadPayload,
  })
  onAddFormatToWork;
  final Future<PlaybackSessionOutcome> Function(MediaListItem item)
  onBeginPlaybackSession;
  final void Function({
    required int positionSeconds,
    required int? durationSeconds,
    required bool isPlaying,
    bool isCompleted,
  })
  onPlaybackProgressChanged;
  final Future<void> Function() onPausePlaybackSession;
  final Future<void> Function() onCompletePlaybackSession;
  final Future<void> Function() onFlushPlaybackSession;
  final void Function() onEndPlaybackSession;
  final double playbackSpeed;
  final void Function(double) onSetPlaybackSpeed;
  final bool pendingPlaybackSync;
  final Future<String?> Function(String fileId) onFetchPlaybackStreamUrl;
  final String? playbackError;
  final Future<String> Function(MediaListItem item) onLoadBookContent;
  final Future<void> Function(String mediaItemId) onRecordMediaItemView;
  final Future<List<MediaFileSummary>> Function(String mediaItemId)
  onFetchMediaFiles;
  final Future<void> Function({
    required String mediaItemId,
    required String fileId,
  })
  onBindMainMediaFile;
  final Future<void> Function({
    required String mediaItemId,
    required MediaUploadPayload uploadPayload,
  })
  onUploadAndBindMainMediaFile;

  final Future<MediaProgress> Function(String mediaItemId) onFetchMediaProgress;
  final Future<MediaProgress> Function({
    required String mediaItemId,
    required int stars,
  })
  onSetMediaItemUserRating;
  final Future<MediaProgress> Function(String mediaItemId)
  onClearMediaItemUserRating;
  final Future<int?> Function(List<String> mediaItemIds) onFetchWorkUserRating;
  final Future<int?> Function({
    required List<String> mediaItemIds,
    required int stars,
  })
  onSetWorkUserRating;
  final Future<void> Function(List<String> mediaItemIds) onClearWorkUserRating;
  final Future<List<MediaComment>> Function(String mediaItemId)
  onFetchMediaComments;
  final Future<MediaComment> Function({
    required String mediaItemId,
    required String text,
  })
  onCreateMediaComment;
  final Future<MediaComment> Function({
    required String commentId,
    required String text,
  })
  onUpdateMediaComment;
  final Future<void> Function(String commentId) onDeleteMediaComment;
  final Future<void> Function({
    required String commentId,
    String? reason,
  })
  onReportMediaComment;
  final Future<List<MediaListItem>> Function({
    required String authorName,
    String? authorId,
  })
  onFetchItemsByAuthor;
  final Future<List<MediaAuthor>> Function(String query) onSearchAuthors;
  final Future<MediaAuthor> Function(String name) onCreateAuthor;
  final Future<bool> Function(String mediaItemId) onAddToShelf;
  final Future<bool> Function(String mediaItemId)? onHasBookOfflineCopy;
  final Future<bool> Function(MediaListItem item)? onDownloadBookForOffline;
  final Future<void> Function({
    required String mediaItemId,
    required String filePath,
    required String filename,
    required String contentType,
  })?
  onSaveAuthorBookLocalFile;

  @override
  State<_MediaItemDetailsPage> createState() => _MediaItemDetailsPageState();
}
