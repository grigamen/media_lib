part of 'library_screen.dart';

// Коробка с настройками: какие действия вызывать при старте просмотра, паузе и смене скорости.

/// Панель «слушать / смотреть» внутри карточки; вся живая логика вынесена в класс состояния ниже.
class _PlayableMediaPanel extends StatefulWidget {
  const _PlayableMediaPanel({
    required this.item,
    required this.onBeginPlaybackSession,
    required this.onRecordMediaItemView,
    required this.onPlaybackProgressChanged,
    required this.onPausePlaybackSession,
    required this.onCompletePlaybackSession,
    required this.onFlushPlaybackSession,
    required this.onEndPlaybackSession,
    required this.playbackSpeed,
    required this.onSetPlaybackSpeed,
    required this.pendingPlaybackSync,
    required this.playbackError,
  });

  final MediaListItem item;
  final Future<PlaybackSessionOutcome> Function(MediaListItem item)
  onBeginPlaybackSession;
  final Future<void> Function(String mediaItemId) onRecordMediaItemView;
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
