import 'package:flutter/material.dart';
import '../themes/theme_provider.dart';

class ProgressBar extends StatefulWidget {
  const ProgressBar({super.key});

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  double _currentPosition = 0.0;
  final double _maxDuration = 180.0; // 3:00 in seconds

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

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
            value: _currentPosition,
            min: 0.0,
            max: _maxDuration,
            onChanged: (value) {
              setState(() {
                _currentPosition = value;
              });
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
                _formatDuration(_currentPosition),
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.w500,
                  color: theme.textMuted,
                ),
              ),
              Text(
                _formatDuration(_maxDuration),
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