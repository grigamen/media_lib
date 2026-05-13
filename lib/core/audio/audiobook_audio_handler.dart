import "dart:async";

import "package:audio_service/audio_service.dart";
import "package:audio_session/audio_session.dart";
import "package:just_audio/just_audio.dart";

/// Глобальный хендлер фонового воспроизведения только для аудиокниг.
AudiobookAudioHandler? audiobookBackgroundHandler;

Future<AudiobookAudioHandler> initAudiobookBackgroundAudio() async {
  audiobookBackgroundHandler = await AudioService.init<AudiobookAudioHandler>(
    builder: AudiobookAudioHandler.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: "ru.medialib.audiobook",
      androidNotificationChannelName: "Аудиокниги",
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      rewindInterval: Duration(seconds: 15),
      fastForwardInterval: Duration(seconds: 15),
    ),
  );
  return audiobookBackgroundHandler!;
}

class AudiobookAudioHandler extends BaseAudioHandler with SeekHandler {
  AudiobookAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (duration != null &&
          current != null &&
          current.duration != duration) {
        mediaItem.add(current.copyWith(duration: duration));
      }
    });
    unawaited(_initAudioSession());
  }

  final AudioPlayer _player = AudioPlayer();

  /// Тот же плеер, к которому подключается UI карточки произведения.
  AudioPlayer get player => _player;

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            unawaited(pause());
            break;
        }
      }
    });
  }

  static Uri? _artUri(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty) {
      return null;
    }
    try {
      final u = Uri.parse(coverUrl);
      if (u.scheme != "http" && u.scheme != "https") {
        return null;
      }
      return u;
    } catch (_) {
      return null;
    }
  }

  /// Загрузка потока и метаданных для уведомления / lock screen.
  Future<void> loadAudiobook({
    required String streamUrl,
    required String mediaItemId,
    required String title,
    String? author,
    String? coverUrl,
    required int initialPositionSeconds,
    required double speed,
  }) async {
    await _player.stop();
    final item = MediaItem(
      id: mediaItemId,
      title: title,
      artist: author,
      album: title,
      artUri: _artUri(coverUrl),
      displayTitle: title,
      displaySubtitle: author,
      playable: true,
    );
    mediaItem.add(item);
    await _player.setAudioSource(
      AudioSource.uri(Uri.parse(streamUrl)),
      initialPosition: Duration(seconds: initialPositionSeconds),
    );
    await _player.setSpeed(speed);
  }

  /// Остановка и сброс уведомления при закрытии сессии в UI (другой контент / выход).
  Future<void> silenceForSessionEnd() async {
    try {
      await _player.stop();
    } catch (_) {}
    mediaItem.add(null);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
