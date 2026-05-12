part of 'library_screen.dart';

class _MediaItemDetailsPage extends StatefulWidget {
  const _MediaItemDetailsPage({
    required this.currentUserId,
    required this.group,
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
    required this.onFetchMediaFiles,
    required this.onBindMainMediaFile,
    required this.onUploadAndBindMainMediaFile,
  });

  final String? currentUserId;
  final _WorkGroup group;
  final List<String> availableGenres;
  final Future<List<MediaLinkItem>> Function(String mediaItemId) onLoadLinks;
  final Future<MediaListItem?> Function(String mediaItemId) onLoadItemById;
  final Future<MediaListItem> Function({
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
  onUpdateItem;
  final Future<MediaListItem> Function({
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

  @override
  State<_MediaItemDetailsPage> createState() => _MediaItemDetailsPageState();
}
