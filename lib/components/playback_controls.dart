import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import '../themes/theme_provider.dart';

class PlaybackControls extends StatefulWidget {
  const PlaybackControls({super.key});

  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls> {
  bool _isPlaying = false;
  double _volume = 0.7;

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Primary Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Repeat Button
            IconButton(
              onPressed: () {},  // TODO: Switch repeat/loop
              icon: const Icon(BootstrapIcons.repeat),
              color: theme.primaryColor,
              iconSize: 20.0,
            ),
            // Skip Previous
            IconButton(
              onPressed: () {}, // TODO
              icon: const Icon(Icons.skip_previous_rounded),
              color: theme.textPrimary,
              iconSize: 28.0,
            ),
            // Play / Pause FAB Button
            RawMaterialButton(
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                  // TODO Call music player
                });
              },
              elevation: 4.0,
              fillColor: theme.primaryColor,
              shape: const CircleBorder(),
              constraints: const BoxConstraints.tightFor(
                width: 56.0,
                height: 56.0,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32.0,
              ),
            ),
            // Skip Next
            IconButton(
              onPressed: () {}, // TODO
              icon: const Icon(Icons.skip_next_rounded),
              color: theme.textPrimary,
              iconSize: 28.0,
            ),
            // Playlist Queue
            IconButton(
              onPressed: () {},  // TODO Open playlist panel
              icon: const Icon(BootstrapIcons.list_nested),
              color: theme.textPrimary,
              iconSize: 20.0,
            ),
          ],
        ),
        const SizedBox(height: 50),
        // Volume Controls Row
        Row(
          children: [
            Icon(
              _volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: theme.textPrimary,
              size: 20.0,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                  activeTrackColor: theme.primaryColor,
                  inactiveTrackColor: theme.primaryColor.withValues(alpha: 0.12),
                  thumbColor: theme.primaryColor,
                ),
                child: Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() {
                      _volume = val;
                      // TODO: Change state in the music player.
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}