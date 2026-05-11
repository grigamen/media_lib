part of 'library_screen.dart';

class _PlayableMediaPanelState extends State<_PlayableMediaPanel> {
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
  bool _didRetryPrepare = false;
  bool _isRecoveringStream = false;
  bool _isSwitchingStream = false;
  late double _currentSpeed;
  double _videoVolume = 1.0;
  bool _showControls = false;
  Timer? _controlsHideTimer;
  List<PlaybackStreamOption> _streamOptions = const [];
  String? _activeStreamFileId;

  bool get _isAudio => widget.item.type == "audiobook";
  bool get _isVideo => widget.item.type == "video";

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.playbackSpeed;
    if (_isVideo) {
      unawaited(_prepareIfNeeded());
    }
  }

  @override
  void didUpdateWidget(covariant _PlayableMediaPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id ||
        widget.item.type != oldWidget.item.type ||
        widget.item.mediaFileId != oldWidget.item.mediaFileId) {
      unawaited(_reinitializeForItemChange());
      return;
    }
    if (widget.playbackSpeed != oldWidget.playbackSpeed &&
        widget.playbackSpeed != _currentSpeed) {
      _currentSpeed = widget.playbackSpeed;
    }
  }

  Future<void> _reinitializeForItemChange() async {
    await _disposePlayers();
    if (!mounted) {
      return;
    }
    setState(() {
      _isInitializing = false;
      _isPlaying = false;
      _isReady = false;
      _localError = null;
      _position = Duration.zero;
      _duration = null;
      _sessionStarted = false;
      _didRetryPrepare = false;
      _isRecoveringStream = false;
      _isSwitchingStream = false;
      _streamOptions = const [];
      _activeStreamFileId = null;
      _videoVolume = 1.0;
      _showControls = false;
    });
    if (_isVideo) {
      unawaited(_prepareIfNeeded());
    }
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    unawaited(_disposePlayers());
    super.dispose();
  }

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
      await _audioPlayer!.dispose();
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

  Future<void> _prepareIfNeeded() async {
    if (_isReady || _isInitializing) {
      return;
    }
    setState(() {
      _isInitializing = true;
      _localError = null;
    });

    final config = await widget.onBeginPlaybackSession(widget.item);
    if (!mounted) {
      return;
    }
    if (config == null) {
      setState(() {
        _isInitializing = false;
        _localError = widget.playbackError ?? "Не удалось подготовить плеер";
      });
      return;
    }

    try {
      if (_isAudio) {
        final player = AudioPlayer();
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
        await player.setUrl(
          config.streamUrl,
          initialPosition: Duration(seconds: config.initialPositionSeconds),
        );
        await player.setSpeed(_currentSpeed);
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
        _streamOptions = config.streamOptions;
        _activeStreamFileId = config.activeStreamFileId;
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

  Future<void> _togglePlayPause() async {
    if (_isSwitchingStream) {
      return;
    }
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

  Future<void> _switchToStream(String fileId) async {
    if (fileId == _activeStreamFileId ||
        _streamOptions.length <= 1 ||
        !_isReady ||
        _isSwitchingStream) {
      return;
    }
    final url = await widget.onFetchPlaybackStreamUrl(fileId);
    if (!mounted) {
      return;
    }
    if (url == null || url.isEmpty) {
      setState(() {
        _localError = "Не удалось получить адрес выбранного файла";
      });
      return;
    }
    final wasPlaying = _isPlaying;
    final seekPos = _position;
    setState(() {
      _isSwitchingStream = true;
      _localError = null;
    });
    try {
      if (_isAudio && _audioPlayer != null) {
        await _audioPlayer!.pause();
        await _audioPlayer!.setUrl(
          url,
          initialPosition: seekPos,
        );
        await _audioPlayer!.setSpeed(_currentSpeed);
        widget.onPlaybackProgressChanged(
          positionSeconds: seekPos.inSeconds,
          durationSeconds: _audioPlayer!.duration?.inSeconds ?? _duration?.inSeconds,
          isPlaying: wasPlaying,
        );
        if (wasPlaying) {
          await _audioPlayer!.play();
        }
        if (!mounted) {
          return;
        }
        setState(() {
          _activeStreamFileId = fileId;
          _isSwitchingStream = false;
          _duration = _audioPlayer!.duration ?? _duration;
        });
      } else if (_isVideo && _videoController != null) {
        await _videoController!.pause();
        _videoController!.removeListener(_onVideoControllerUpdate);
        final old = _videoController!;
        _videoController = null;
        await old.dispose();
        if (!mounted) {
          return;
        }
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _videoController = controller;
        await controller.initialize();
        await controller.setVolume(_videoVolume);
        await controller.setPlaybackSpeed(_currentSpeed);
        if (seekPos > Duration.zero) {
          await controller.seekTo(seekPos);
        }
        controller.addListener(_onVideoControllerUpdate);
        if (wasPlaying) {
          await controller.play();
        }
        if (!mounted) {
          return;
        }
        final v = controller.value;
        setState(() {
          _activeStreamFileId = fileId;
          _isSwitchingStream = false;
          _position = v.position;
          _duration = v.duration.inSeconds > 0 ? v.duration : _duration;
          _isPlaying = v.isPlaying;
        });
        widget.onPlaybackProgressChanged(
          positionSeconds: v.position.inSeconds,
          durationSeconds: v.duration.inSeconds > 0 ? v.duration.inSeconds : null,
          isPlaying: v.isPlaying,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSwitchingStream = false;
          _localError = _humanizePlaybackError(error);
        });
      }
    }
  }

  Future<void> _changeSpeed(double speed) async {
    _currentSpeed = speed;
    widget.onSetPlaybackSpeed(speed);
    if (_isAudio && _audioPlayer != null) {
      await _audioPlayer!.setSpeed(speed);
    } else if (_isVideo && _videoController != null) {
      await _videoController!.setPlaybackSpeed(speed);
    }
    if (mounted) {
      setState(() {});
    }
    _showControlsTemporarily();
  }

  Future<void> _toggleMute() async {
    if (!_isVideo || _videoController == null) {
      return;
    }
    final nextVolume = _videoVolume > 0 ? 0.0 : 1.0;
    await _videoController!.setVolume(nextVolume);
    if (mounted) {
      setState(() {
        _videoVolume = nextVolume;
      });
    }
    _showControlsTemporarily();
  }

  Future<void> _openFullscreenVideo(BuildContext context) async {
    final controller = _videoController;
    if (!_isVideo || controller == null || !controller.value.isInitialized) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              body: SafeArea(
                child: GestureDetector(
                  onTap: _toggleControlsVisibility,
                  onVerticalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 500) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Stack(
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      if (_showControls)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip:
                                    _videoVolume > 0
                                        ? "Выключить звук"
                                        : "Включить звук",
                                onPressed: _toggleMute,
                                color: Colors.white,
                                icon: Icon(
                                  _videoVolume > 0
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                ),
                              ),
                              PopupMenuButton<double>(
                                tooltip: "Скорость",
                                initialValue: _currentSpeed,
                                onSelected: _changeSpeed,
                                itemBuilder:
                                    (context) => _speedOptions
                                        .map(
                                          (speed) => PopupMenuItem<double>(
                                            value: speed,
                                            child: Text(
                                              "${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x",
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                icon: const Icon(
                                  Icons.speed,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      if (_showControls)
                        ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            final totalSeconds = value.duration.inSeconds;
                            final currentSeconds = value.position.inSeconds
                                .clamp(0, totalSeconds > 0 ? totalSeconds : 0);
                            return Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white30,
                                        thumbColor: Colors.white,
                                        trackHeight: 2,
                                      ),
                                      child: Slider(
                                        value: currentSeconds.toDouble(),
                                        max:
                                            (totalSeconds > 0
                                                    ? totalSeconds
                                                    : 1)
                                                .toDouble(),
                                        onChanged:
                                            (_isReady && totalSeconds > 0)
                                                ? _seekTo
                                                : null,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _formatDuration(value.position),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          onPressed:
                                              _isInitializing
                                                  ? null
                                                  : _togglePlayPause,
                                          color: Colors.white,
                                          icon: Icon(
                                            value.isPlaying
                                                ? Icons.pause
                                                : Icons.play_arrow,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatDuration(value.duration),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
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
    if (!_isPlaying) {
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

  String _formatDuration(Duration? duration) {
    if (duration == null) {
      return "--:--";
    }
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, "0");
    final seconds = (totalSeconds % 60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
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

  @override
  Widget build(BuildContext context) {
    final currentError = _localError ?? widget.playbackError;
    final totalSeconds = (_duration ?? Duration.zero).inSeconds;
    final currentSeconds = _position.inSeconds.clamp(
      0,
      totalSeconds > 0 ? totalSeconds : 0,
    );
    final isVideoReady = _videoController?.value.isInitialized == true;
    final previewAspectRatio =
        isVideoReady ? _videoController!.value.aspectRatio : 16 / 9;
    final hasCover = widget.item.coverUrl?.isNotEmpty == true;

    if (_isAudio) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child:
                          hasCover
                              ? Image.network(
                                widget.item.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Container(
                                      color: Colors.black12,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.headphones),
                                    ),
                              )
                              : Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(Icons.headphones),
                              ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Аудиоплеер",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (_streamOptions.length > 1)
                    PopupMenuButton<String>(
                      tooltip: "Источник",
                      enabled: !_isInitializing && !_isSwitchingStream,
                      onSelected: (id) {
                        unawaited(_switchToStream(id));
                      },
                      itemBuilder:
                          (context) => _streamOptions
                              .map(
                                (o) => PopupMenuItem<String>(
                                  value: o.fileId,
                                  child: Text(o.label),
                                ),
                              )
                              .toList(growable: false),
                      child: Icon(
                        Icons.layers_outlined,
                        color:
                            _activeStreamFileId != null
                                ? Theme.of(context).colorScheme.primary
                                : null,
                      ),
                    ),
                  PopupMenuButton<double>(
                    tooltip: "Скорость",
                    initialValue: _currentSpeed,
                    onSelected: _changeSpeed,
                    itemBuilder:
                        (context) => _speedOptions
                            .map(
                              (speed) => PopupMenuItem<double>(
                                value: speed,
                                child: Text(
                                  "${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x",
                                ),
                              ),
                            )
                            .toList(growable: false),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Text(
                        "${_currentSpeed.toStringAsFixed(_currentSpeed == _currentSpeed.roundToDouble() ? 0 : 2)}x",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Slider(
                value: currentSeconds.toDouble(),
                max: (totalSeconds > 0 ? totalSeconds : 1).toDouble(),
                onChanged: (_isReady && totalSeconds > 0) ? _seekTo : null,
              ),
              Row(
                children: [
                  Text(_formatDuration(_position)),
                  const Spacer(),
                  Text(_formatDuration(_duration)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _isInitializing ? null : _togglePlayPause,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_isPlaying ? "Пауза" : "Воспроизвести"),
                ),
              ),
              if (_isInitializing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_isSwitchingStream) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (currentError != null) ...[
                const SizedBox(height: 8),
                Text(
                  currentError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _toggleControlsVisibility,
              child: AspectRatio(
                aspectRatio: previewAspectRatio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_isVideo && isVideoReady)
                        VideoPlayer(_videoController!)
                      else if (hasCover)
                        Image.network(
                          widget.item.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                color: Colors.black12,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  size: 40,
                                ),
                              ),
                        )
                      else
                        Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: Icon(
                            _isAudio ? Icons.headphones : Icons.ondemand_video,
                            size: 40,
                          ),
                        ),
                      AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(color: Colors.black38),
                      ),
                      if (_isInitializing)
                        const Center(child: CircularProgressIndicator()),
                      AnimatedOpacity(
                        opacity: _showControls || !_isPlaying ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Center(
                          child: IconButton.filledTonal(
                            onPressed:
                                _isInitializing ? null : _togglePlayPause,
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      if (_showControls)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_streamOptions.length > 1)
                                PopupMenuButton<String>(
                                  tooltip: "Источник",
                                  enabled: !_isInitializing && !_isSwitchingStream,
                                  onSelected: (id) {
                                    unawaited(_switchToStream(id));
                                  },
                                  itemBuilder:
                                      (context) => _streamOptions
                                          .map(
                                            (o) => PopupMenuItem<String>(
                                              value: o.fileId,
                                              child: Text(o.label),
                                            ),
                                          )
                                          .toList(growable: false),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.layers_outlined,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              if (_isVideo && isVideoReady)
                                IconButton(
                                  tooltip:
                                      _videoVolume > 0
                                          ? "Выключить звук"
                                          : "Включить звук",
                                  onPressed: _toggleMute,
                                  color: Colors.white,
                                  icon: Icon(
                                    _videoVolume > 0
                                        ? Icons.volume_up
                                        : Icons.volume_off,
                                  ),
                                ),
                              if (_isVideo && isVideoReady)
                                IconButton(
                                  tooltip: "Полный экран",
                                  onPressed:
                                      () => _openFullscreenVideo(context),
                                  color: Colors.white,
                                  icon: const Icon(Icons.fullscreen),
                                ),
                              PopupMenuButton<double>(
                                tooltip: "Скорость",
                                initialValue: _currentSpeed,
                                onSelected: _changeSpeed,
                                itemBuilder:
                                    (context) => _speedOptions
                                        .map(
                                          (speed) => PopupMenuItem<double>(
                                            value: speed,
                                            child: Text(
                                              "${speed.toStringAsFixed(speed == speed.roundToDouble() ? 0 : 2)}x",
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${_currentSpeed.toStringAsFixed(_currentSpeed == _currentSpeed.roundToDouble() ? 0 : 2)}x",
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_showControls)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white30,
                                    thumbColor: Colors.white,
                                    trackHeight: 2,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 5,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 10,
                                    ),
                                  ),
                                  child: Slider(
                                    value: currentSeconds.toDouble(),
                                    max:
                                        (totalSeconds > 0 ? totalSeconds : 1)
                                            .toDouble(),
                                    onChanged:
                                        (_isReady && totalSeconds > 0)
                                            ? _seekTo
                                            : null,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(_position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatDuration(_duration),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (currentError != null) ...[
              const SizedBox(height: 8),
              Text(
                currentError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
