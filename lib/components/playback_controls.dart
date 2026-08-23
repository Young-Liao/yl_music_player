import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/utils/lyrics_handler.dart';
import 'package:yl_music_player/utils/playlist_manager.dart';
import 'package:yl_music_player/utils/track_stepper_mixin.dart';
import '../pages/playlist_panel.dart';
import '../themes/theme_provider.dart';

class PlaybackControls extends StatefulWidget {
  final AudioPlayerController audioController;
  final PlaylistManager playlistManager;
  final LyricsHandler lyricsManager;

  const PlaybackControls({
    super.key,
    required this.audioController,
    required this.playlistManager,
    required this.lyricsManager,
  });

  @override
  State<PlaybackControls> createState() => _PlaybackControlsState();
}

class _PlaybackControlsState extends State<PlaybackControls>
    with TrackStepperMixin {
  bool get _isPlaying => audioController.isPlaying;

  @override
  AudioPlayerController get audioController => widget.audioController;

  @override
  PlaylistManager get playlistManager => widget.playlistManager;

  @override
  LyricsHandler get lyricsHandler => widget.lyricsManager;

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
              onPressed: () => audioController.loopType == LoopType.repeat
                  ? audioController.loopType = LoopType.loop
                  : audioController.loopType = LoopType.repeat,
              icon: audioController.loopType == LoopType.repeat
                  ? const Icon(BootstrapIcons.repeat_1)
                  : const Icon(BootstrapIcons.repeat),
              color: theme.primaryColor,
              iconSize: 20.0,
            ),
            // Skip Previous
            IconButton(
              onPressed: prevSong,
              icon: const Icon(Icons.skip_previous_rounded),
              color: theme.textPrimary,
              iconSize: 28.0,
            ),
            // Play / Pause FAB Button
            RawMaterialButton(
              onPressed: () {
                setState(() {
                  audioController.setPlaying(!_isPlaying);
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
              onPressed: nextSong,
              icon: const Icon(Icons.skip_next_rounded),
              color: theme.textPrimary,
              iconSize: 28.0,
            ),
            // Playlist Queue
            IconButton(
              onPressed: () {
                PlaylistPanel.show(
                  context,
                  isPlaying: _isPlaying,
                  playlistManager: playlistManager,
                  audioController: audioController,
                  onPlayTrack: (String path) async {
                    // audioController.loadTrack(path, isLocalFile: true);
                    await loadSong(TrackMetadataItem.onlyPath(path));
                    playlistManager.updateCurrentIndexWithPath(path);
                    await audioController.setPlaying(true);
                    if (mounted) {
                      setState(() {});
                    }
                  },
                );
              },
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
              audioController.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              color: theme.textPrimary,
              size: 20.0,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 10.0,
                  ),
                  activeTrackColor: theme.primaryColor,
                  inactiveTrackColor: theme.primaryColor.withValues(
                    alpha: 0.12,
                  ),
                  thumbColor: theme.primaryColor,
                ),
                child: Slider(
                  value: audioController.volume,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (val) {
                    setState(() {
                      audioController.setVolume(val);
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
