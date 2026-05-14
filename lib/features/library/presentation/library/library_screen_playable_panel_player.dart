part of 'library_screen.dart';

// Рисунок поверх видео: кнопки, ползунок времени, двойное нажатие по краям чтобы отмотать.

/// Всё, что касается картинки видео и жестов; звук обрабатывается в другой части.
mixin _PlayableMediaPanelPlayer on _PlayableMediaPanelPlayerCore {
  /// Двойной тап слева или справа по краю — откатить или продвинуть на 10 секунд; по центру — пауза или пуск.
  static const double _doubleTapSideFraction = 0.28;

  void _handleVideoSurfaceDoubleTap(TapDownDetails details, double width) {
    if (!_isReady || width <= 0) {
      return;
    }
    final x = details.localPosition.dx;
    if (x < width * _doubleTapSideFraction) {
      unawaited(_seekVideoRelative(-10));
    } else if (x > width * (1 - _doubleTapSideFraction)) {
      unawaited(_seekVideoRelative(10));
    } else {
      unawaited(_togglePlayPause());
    }
    _showControlsTemporarily();
  }

  Widget _videoQuickSeekBar({
    required Color iconColor,
    required Widget center,
  }) {
    final enabled =
        _isReady && _videoController != null && !_isInitializing;
    Widget btn({required int delta, required IconData icon, required String tip}) {
      return IconButton(
        tooltip: tip,
        onPressed: enabled ? () => unawaited(_seekVideoRelative(delta)) : null,
        icon: Icon(icon, color: iconColor, size: 22),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        btn(
          delta: -30,
          icon: Icons.replay_30,
          tip: "Назад на 30 секунд",
        ),
        btn(
          delta: -10,
          icon: Icons.replay_10,
          tip: "Назад на 10 секунд",
        ),
        center,
        btn(
          delta: 10,
          icon: Icons.forward_10,
          tip: "Вперёд на 10 секунд",
        ),
        btn(
          delta: 30,
          icon: Icons.forward_30,
          tip: "Вперёд на 30 секунд",
        ),
      ],
    );
  }

  /// Одна строка: сколько прошло, ползунок и сколько всего — поверх затемнённого видео.
  Widget _videoTimeSliderRow({
    required BuildContext context,
    required double currentSeconds,
    required int totalSeconds,
    required String positionLabel,
    required String durationLabel,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 64,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              positionLabel,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white30,
              thumbColor: Colors.white,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            ),
            child: Slider(
              value: currentSeconds,
              max: (totalSeconds > 0 ? totalSeconds : 1).toDouble(),
              onChanged:
                  (_isReady && totalSeconds > 0) ? _seekTo : null,
            ),
          ),
        ),
        SizedBox(
          width: 64,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              durationLabel,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    );
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
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: AspectRatio(
                          aspectRatio: controller.value.aspectRatio,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _toggleControlsVisibility,
                          onDoubleTapDown: (details) {
                            _handleVideoSurfaceDoubleTap(
                              details,
                              constraints.maxWidth,
                            );
                          },
                          onVerticalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            if (velocity > 500) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: const SizedBox.expand(),
                        ),
                      ),
                      if (_showControls)
                        SafeArea(
                          child: Stack(
                            children: [
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
                              ValueListenableBuilder<VideoPlayerValue>(
                                valueListenable: controller,
                                builder: (context, value, child) {
                                  final totalSeconds = value.duration.inSeconds;
                                  final currentSeconds = value.position.inSeconds
                                      .clamp(
                                        0,
                                        totalSeconds > 0 ? totalSeconds : 0,
                                      );
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
                                          _videoTimeSliderRow(
                                            context: context,
                                            currentSeconds:
                                                currentSeconds.toDouble(),
                                            totalSeconds: totalSeconds,
                                            positionLabel: _formatVideoTime(
                                              value.position,
                                              value.duration,
                                              value.position,
                                            ),
                                            durationLabel: _formatVideoTime(
                                              value.duration,
                                              value.duration,
                                              value.position,
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
                                                value.isPlaying
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
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

}
