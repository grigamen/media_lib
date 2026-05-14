part of 'library_screen.dart';

// Склеивает всё вместе: при открытии карточки для видео сразу готовим плеер, следим за поворотом экрана.

/// Жизненный цикл панели: от начала до закрытия, плюс отрисовка либо звуковой карточки, либо видео с поверхностью.
class _PlayableMediaPanelState extends State<_PlayableMediaPanel>
    with _PlayableMediaPanelFields, WidgetsBindingObserver,
        _PlayableMediaPanelPlayerCore, _PlayableMediaPanelPlayer {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }
    // Поворот экрана: не сбрасываем панель; только перезапускаем таймер автоскрытия.
    _scheduleControlsAutoHideIfPlaying();
  }

  /// Другая вкладка или другой файл — полностью обнуляем плеер и для видео заново запрашиваем с сервера.
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
      _videoVolume = 1.0;
      _showControls = false;
    });
    if (_isVideo) {
      unawaited(_prepareIfNeeded());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlsHideTimer?.cancel();
    unawaited(_disposePlayers());
    super.dispose();
  }

  /// Рисуем либо компактную аудио-карточку с обложкой, либо видео с кнопками; показываем ошибки простым текстом.
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
                  PopupMenuButton<double>(
                    tooltip: "Скорость",
                    initialValue: _currentSpeed,
                    onSelected: _changeSpeed,
                    itemBuilder:
                        (context) => _PlayableMediaPanelFields._speedOptions
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
            AspectRatio(
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
                    IgnorePointer(
                      ignoring: !_showControls,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(color: Colors.black38),
                      ),
                    ),
                    if (_isInitializing)
                      const Center(child: CircularProgressIndicator()),
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _toggleControlsVisibility,
                            onDoubleTapDown: (details) {
                              _handleVideoSurfaceDoubleTap(
                                details,
                                constraints.maxWidth,
                              );
                            },
                            child: const SizedBox.expand(),
                          );
                        },
                      ),
                    ),
                    IgnorePointer(
                      ignoring:
                          (_isVideo && isVideoReady && _showControls) ||
                          (!_showControls && _isPlaying),
                      child: AnimatedOpacity(
                        opacity:
                            (_isVideo && isVideoReady && _showControls)
                                ? 0.0
                                : (_showControls || !_isPlaying ? 1.0 : 0.0),
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
                    ),
                    if (_showControls)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                  (context) => _PlayableMediaPanelFields._speedOptions
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
                                _videoTimeSliderRow(
                                  context: context,
                                  currentSeconds: currentSeconds.toDouble(),
                                  totalSeconds: totalSeconds,
                                  positionLabel: _formatVideoTime(
                                    _position,
                                    _duration ?? Duration.zero,
                                    _position,
                                  ),
                                  durationLabel: _formatVideoTime(
                                    _duration,
                                    _duration ?? Duration.zero,
                                    _position,
                                  ),
                                ),
                                _videoQuickSeekBar(
                                  iconColor: Colors.white,
                                  center: IconButton(
                                    onPressed:
                                        _isInitializing
                                            ? null
                                            : _togglePlayPause,
                                    color: Colors.white,
                                    icon: Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
