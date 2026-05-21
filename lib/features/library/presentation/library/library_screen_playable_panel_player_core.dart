part of 'library_screen.dart';

// Тяжёлая часть: просим у сервера ссылку и настройки, подключаем звук через фоновый режим или видео через стандартный плеер.

/// Запуск и остановка воспроизведения, перемотка, связь с сервером по прогрессу.
mixin _PlayableMediaPanelPlayerCore
    on _PlayableMediaPanelFields, WidgetsBindingObserver {
  /// Выключаем звук/картинку и при необходимости говорим серверу, что сессия просмотра закончена.
  Future<void> _disposePlayers() async {
    await _audioPositionSub?.cancel();
    await _audioDurationSub?.cancel();
    await _audioPlayerStateSub?.cancel();
    await _audioPlaybackEventSub?.cancel();
    _audioPositionSub = null;
    _audioDurationSub = null;
    _audioPlayerStateSub = null;
    _audioPlaybackEventSub = null;
    if (_audioPlayer != null) {
      if (_isAudio) {
        await audiobookBackgroundHandler?.silenceForSessionEnd();
      } else {
        await _audioPlayer!.dispose();
      }
      _audioPlayer = null;
    }
    if (_videoController != null) {
      _videoController!.removeListener(_onVideoControllerUpdate);
      await _videoController!.dispose();
      _videoController = null;
    }
    if (_sessionStarted) {
      await widget.onFlushPlaybackSession();
      widget.onEndPlaybackSession();
      _sessionStarted = false;
    }
  }

  /// Первый раз или после ошибки: получаем от сервера ссылку и с какой секунды продолжить, поднимаем плеер.
  Future<void> _prepareIfNeeded() async {
    if (_isReady || _isInitializing) {
      return;
    }
    setState(() {
      _isInitializing = true;
      _localError = null;
    });

    final outcome = await widget.onBeginPlaybackSession(widget.item);
    if (!mounted) {
      return;
    }
    if (outcome.config == null) {
      setState(() {
        _isInitializing = false;
        _localError =
            outcome.errorMessage ??
            widget.playbackError ??
            "Не удалось подготовить плеер";
      });
      return;
    }
    final config = outcome.config!;
    try {
      if (_isAudio) {
        final handler = audiobookBackgroundHandler;
        if (handler == null) {
          setState(() {
            _isInitializing = false;
            _localError =
                "Фоновое воспроизведение недоступно (сервис не инициализирован).";
          });
          return;
        }
        await handler.loadAudiobook(
          streamUrl: config.streamUrl,
          mediaItemId: config.mediaItemId,
          title: widget.item.title,
          author: widget.item.author,
          coverUrl: widget.item.coverUrl,
          initialPositionSeconds: config.initialPositionSeconds,
          speed: _currentSpeed,
        );
        final player = handler.player;
        _audioPlayer = player;
        _audioPositionSub = player.positionStream.listen((position) {
          final totalDuration = _duration ?? player.duration;
          widget.onPlaybackProgressChanged(
            positionSeconds: position.inSeconds,
            durationSeconds: totalDuration?.inSeconds,
            isPlaying: player.playing,
            isCompleted: false,
          );
          if (mounted) {
            setState(() {
              _position = position;
              _duration = totalDuration;
            });
          }
        });
        _audioDurationSub = player.durationStream.listen((duration) {
          if (duration != null && mounted) {
            setState(() {
              _duration = duration;
            });
          }
        });
        _audioPlayerStateSub = player.playerStateStream.listen((state) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isPlaying = state.playing;
          });
          if (state.processingState == ProcessingState.completed) {
            widget.onPlaybackProgressChanged(
              positionSeconds: (_duration ?? _position).inSeconds,
              durationSeconds: _duration?.inSeconds,
              isPlaying: false,
              isCompleted: true,
            );
            unawaited(widget.onCompletePlaybackSession());
          }
        });
        _audioPlaybackEventSub = player.playbackEventStream.listen(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            unawaited(_recoverFromStreamError(error));
            if (!mounted) {
              return;
            }
            setState(() {
              _localError = _humanizePlaybackError(error);
            });
          },
        );
        if (!mounted) {
          return;
        }
        _position = Duration(seconds: config.initialPositionSeconds);
        _duration = player.duration ?? _duration;
      } else if (_isVideo) {
        final controller = VideoPlayerController.networkUrl(
          Uri.parse(config.streamUrl),
        );
        _videoController = controller;
        await controller.initialize();
        await controller.setVolume(_videoVolume);
        if (!mounted) {
          return;
        }
        if (config.initialPositionSeconds > 0) {
          await controller.seekTo(
            Duration(seconds: config.initialPositionSeconds),
          );
        }
        await controller.setPlaybackSpeed(_currentSpeed);
        if (!mounted) {
          return;
        }
        controller.addListener(_onVideoControllerUpdate);
        _position = controller.value.position;
        _duration = controller.value.duration;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _isReady = true;
        _isInitializing = false;
        _sessionStarted = true;
        _didRetryPrepare = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isRetryablePlaybackError(error) && !_didRetryPrepare) {
        _didRetryPrepare = true;
        await _disposePlayers();
        if (!mounted) {
          return;
        }
        setState(() {
          _isInitializing = false;
          _localError = null;
        });
        await _prepareIfNeeded();
        return;
      }
      setState(() {
        _isInitializing = false;
        _localError = _humanizePlaybackError(error);
      });
    }
  }

  /// Каждый кадр видео: обновляем полоску прогресса и при конце ролика сообщаем наружу.
  void _onVideoControllerUpdate() {
    final controller = _videoController;
    if (controller == null || !mounted) {
      return;
    }
    final value = controller.value;
    setState(() {
      _position = value.position;
      _duration = value.duration;
      _isPlaying = value.isPlaying;
    });
    widget.onPlaybackProgressChanged(
      positionSeconds: value.position.inSeconds,
      durationSeconds:
          value.duration.inSeconds > 0 ? value.duration.inSeconds : null,
      isPlaying: value.isPlaying,
      isCompleted: value.isCompleted,
    );
    if (value.isCompleted) {
      unawaited(widget.onCompletePlaybackSession());
    }
  }

  /// Один раз за сессию панели: засчитать просмотр при реальном старте воспроизведения.
  Future<void> _recordViewOnPlaybackStart() async {
    if (_viewRecordedForSession) {
      return;
    }
    _viewRecordedForSession = true;
    await widget.onRecordMediaItemView(widget.item.id);
  }

  /// Пауза или продолжить: для звука и видео по-разному, плюс при паузе сохраняем место на сервере.
  Future<void> _togglePlayPause() async {
    await _prepareIfNeeded();
    if (!_isReady) {
      return;
    }
    if (_isAudio && _audioPlayer != null) {
      try {
        if (_audioPlayer!.playing) {
          await _audioPlayer!.pause();
          await widget.onPausePlaybackSession();
        } else {
          await _recordViewOnPlaybackStart();
          await _audioPlayer!.play();
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _localError = _humanizePlaybackError(error);
          });
        }
      }
      if (mounted) {
        setState(() {
          _isPlaying = _audioPlayer!.playing;
        });
      }
      _showControlsTemporarily();
      return;
    }
    if (_isVideo && _videoController != null) {
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
        await widget.onPausePlaybackSession();
      } else {
        await _recordViewOnPlaybackStart();
        await _videoController!.play();
      }
      if (mounted) {
        setState(() {
          _isPlaying = _videoController!.value.isPlaying;
        });
      }
      _showControlsTemporarily();
    }
  }

  Future<void> _seekTo(double value) async {
    final seekPosition = Duration(seconds: value.round());
    if (_isAudio && _audioPlayer != null) {
      await _audioPlayer!.seek(seekPosition);
      widget.onPlaybackProgressChanged(
        positionSeconds: seekPosition.inSeconds,
        durationSeconds: _duration?.inSeconds,
        isPlaying: _audioPlayer!.playing,
      );
    } else if (_isVideo && _videoController != null) {
      await _videoController!.seekTo(seekPosition);
      widget.onPlaybackProgressChanged(
        positionSeconds: seekPosition.inSeconds,
        durationSeconds: _duration?.inSeconds,
        isPlaying: _videoController!.value.isPlaying,
      );
    }
    _showControlsTemporarily();
  }

  Future<void> _seekVideoRelative(int deltaSeconds) async {
    if (!_isVideo || _videoController == null || !_isReady) {
      return;
    }
    final dur = _duration ?? _videoController!.value.duration;
    final maxSec = dur.inSeconds > 0 ? dur.inSeconds : 0;
    var nextSec = _position.inSeconds + deltaSeconds;
    if (nextSec < 0) {
      nextSec = 0;
    }
    if (maxSec > 0 && nextSec > maxSec) {
      nextSec = maxSec;
    }
    await _seekTo(nextSec.toDouble());
  }

  void _scheduleControlsAutoHideIfPlaying() {
    _controlsHideTimer?.cancel();
    if (!_showControls || !_isPlaying) {
      return;
    }
    _controlsHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showControls = false;
      });
    });
  }

  void _toggleControlsVisibility() {
    if (_showControls) {
      _controlsHideTimer?.cancel();
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
      return;
    }
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    _controlsHideTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _showControls = true;
    });
    _scheduleControlsAutoHideIfPlaying();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return "--:--";
    }
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, "0");
    final seconds = (totalSeconds % 60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  /// Как показать время для длинного ролика: если ролик больше часа, добавляем часы в формат `ч:мм:сс`.
  String _formatVideoTime(
    Duration? time,
    Duration totalReference,
    Duration positionReference,
  ) {
    if (time == null) {
      return "--:--";
    }
    final showHours =
        totalReference.inSeconds >= 3600 ||
        (totalReference.inSeconds == 0 && positionReference.inSeconds >= 3600);
    final s = time.inSeconds;
    if (!showHours) {
      final m = s ~/ 60;
      final sec = s % 60;
      return "${m.toString().padLeft(2, "0")}:${sec.toString().padLeft(2, "0")}";
    }
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return "$h:${m.toString().padLeft(2, "0")}:${sec.toString().padLeft(2, "0")}";
  }

  String _humanizePlaybackError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains("404")) {
      return "Аудиофайл не найден (HTTP 404). Проверьте, что файл загружен и file_id актуален.";
    }
    if (lower.contains("sockettimeoutexception") ||
        lower.contains("failed to connect") ||
        lower.contains("connection timed out")) {
      return "Не удалось подключиться к хранилищу аудио. Для эмулятора проверьте доступность endpoint на 10.0.2.2.";
    }
    if (lower.contains("cleartext")) {
      return "Поток заблокирован политикой cleartext HTTP. Нужен HTTPS или network security config.";
    }
    if (lower.contains("source error")) {
      return "Источник аудио недоступен (обычно 404/403). Проверьте, что файл существует в storage и media_file_id актуален.";
    }
    return "Ошибка воспроизведения: $raw";
  }

  bool _isRetryablePlaybackError(Object error) {
    final lower = error.toString().toLowerCase();
    return lower.contains("404") ||
        lower.contains("403") ||
        lower.contains("response code");
  }

  Future<void> _recoverFromStreamError(Object error) async {
    if (!mounted || !_isRetryablePlaybackError(error)) {
      return;
    }
    if (_didRetryPrepare || _isRecoveringStream) {
      return;
    }
    _isRecoveringStream = true;
    _didRetryPrepare = true;
    final shouldResumePlayback = _isPlaying;
    try {
      await _disposePlayers();
      if (!mounted) {
        return;
      }
      await _prepareIfNeeded();
      if (!mounted || !shouldResumePlayback) {
        return;
      }
      if (_isAudio && _audioPlayer != null) {
        await _audioPlayer!.play();
      } else if (_isVideo && _videoController != null) {
        await _videoController!.play();
      }
    } catch (_) {
      // Keep original playback error visible for the user.
    } finally {
      _isRecoveringStream = false;
    }
  }
}
