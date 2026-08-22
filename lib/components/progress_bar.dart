import 'package:flutter/material.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import '../themes/theme_provider.dart';

class ProgressBar extends StatefulWidget {
  final AudioPlayerController controller;
  final ValueChanged<double>? onSliderValueChanged;

  const ProgressBar({
    super.key,
    required this.controller,
    required this.onSliderValueChanged,
  });

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  double _lastNotifiedPosition = -1.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChange);
      widget.controller.addListener(_handleControllerChange);
    }
  }

  void _handleControllerChange() {
    // Notify parent when position changes during normal playback (if not dragging)
    if (!_isDragging) {
      final currentSeconds = widget.controller.position.inSeconds.toDouble();
      if (currentSeconds != _lastNotifiedPosition) {
        _lastNotifiedPosition = currentSeconds;
        widget.onSliderValueChanged?.call(currentSeconds);
      }
    }
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final controller = widget.controller;

    final maxDurationSeconds = controller.duration.inSeconds.toDouble();
    final currentPositionSeconds = controller.position.inSeconds.toDouble();

    final sliderValue = _isDragging
        ? _dragValue
        : currentPositionSeconds.clamp(0.0, maxDurationSeconds > 0 ? maxDurationSeconds : 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern Slider Configuration
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            activeTrackColor: theme.primaryColor,
            inactiveTrackColor: theme.primaryColor.withValues(alpha: 0.12),
            thumbColor: theme.primaryColor,
          ),
          child: Slider(
            value: sliderValue,
            min: 0.0,
            max: maxDurationSeconds,
            onChangeStart: (value) {
              setState(() {
                _isDragging = true;
                _dragValue = value;
              });
              widget.onSliderValueChanged?.call(value);
            },
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
              widget.onSliderValueChanged?.call(value);
            },
            onChangeEnd: (value) {
              controller.seek(Duration(seconds: value.toInt()));
              setState(() {
                _isDragging = false;
              });
              widget.onSliderValueChanged?.call(value);
            },
          ),
        ),
        // Timestamp Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(
                  _isDragging
                      ? _dragValue.toDouble()
                      : controller.position.inSeconds.toDouble(),
                ),
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: theme.textMuted,
                ),
              ),
              Text(
                _formatDuration(maxDurationSeconds),
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: theme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}