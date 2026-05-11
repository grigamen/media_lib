part of 'library_screen.dart';

class _PlayableMediaPanel extends StatefulWidget {
  const _PlayableMediaPanel({
    required this.item,
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
  });

  final MediaListItem item;
  final Future<PlaybackSessionConfig?> Function(MediaListItem item)
  onBeginPlaybackSession;
  final Future<String?> Function(String fileId) onFetchPlaybackStreamUrl;
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
  final String? playbackError;

  @override
  State<_PlayableMediaPanel> createState() => _PlayableMediaPanelState();
}
