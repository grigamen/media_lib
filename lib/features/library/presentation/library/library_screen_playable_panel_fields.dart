part of 'library_screen.dart';

// Поля «внутренней памяти» плеера: плееры, таймер скрытия кнопок, флаги «ещё грузится» / «уже можно смотреть».

/// Общие переменные для звука и видео в карточке, чтобы разные части кода не дублировали одно и то же.
mixin _PlayableMediaPanelFields on State<_PlayableMediaPanel> {
  static const List<double> _speedOptions = [0.75, 1.0, 1.25, 1.5, 2.0];

  AudioPlayer? _audioPlayer;
  VideoPlayerController? _videoController;
  StreamSubscription<Duration>? _audioPositionSub;
  StreamSubscription<Duration?>? _audioDurationSub;
  StreamSubscription<PlayerState>? _audioPlayerStateSub;
  StreamSubscription<PlaybackEvent>? _audioPlaybackEventSub;

  bool _isInitializing = false;
  bool _isPlaying = false;
  bool _isReady = false;
  String? _localError;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _sessionStarted = false;
  bool _viewRecordedForSession = false;
  bool _didRetryPrepare = false;
  bool _isRecoveringStream = false;
  late double _currentSpeed;
  double _videoVolume = 1.0;
  bool _showControls = false;
  Timer? _controlsHideTimer;

  bool get _isAudio => widget.item.type == "audiobook";
  bool get _isVideo => widget.item.type == "video";
}
