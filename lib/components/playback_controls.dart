import 'dart:async';

import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/controllers/lyrics_handler.dart';
import 'package:yl_music_player/controllers/playlist_manager.dart';
import 'package:yl_music_player/utils/track_stepper_mixin.dart';
import '../main.dart';
import '../pages/playlist_panel.dart';
import '../themes/theme_provider.dart';
import '../utils/data_structures/track_metadata_item.dart';
import '../utils/link_service.dart';

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
  bool _isPanelOpen =
      false; // Guard to prevent stacking multiple playlist panels

  StreamSubscription<String>? _linkSubscription;

  @override
  AudioPlayerController get audioController => widget.audioController;

  @override
  PlaylistManager get playlistManager => widget.playlistManager;

  @override
  LyricsHandler get lyricsHandler => widget.lyricsManager;

  @override
  void initState() {
    super.initState();
    _bindSystemMediaCallbacks();
    _initAppLinksListener();
  }

  void _initAppLinksListener() {
    _linkSubscription = LinkService.instance.linkStream.listen((
      String path,
    ) async {
      await widget.playlistManager.addFileNextToCurrent(path);
      _showPlaylistPanel(autoPickFile: false);
      await nextSong();
      await audioController.setPlaying(true);
    });
  }

  /// Binds system Control Center / Lockscreen actions to internal player logic
  void _bindSystemMediaCallbacks() {
    systemMediaHandler.onPlayCallback = () {
      if (!audioController.isPlaying) {
        _onTriggerPlayback();
      }
    };

    systemMediaHandler.onPauseCallback = () {
      if (audioController.isPlaying) {
        _onTriggerPlayback();
      }
    };

    systemMediaHandler.onSkipNextCallback = () {
      nextSong();
    };

    systemMediaHandler.onSkipPreviousCallback = () {
      prevSong();
    };
  }

  @override
  void dispose() {
    // Unbind callbacks when leaving PlayerPage to prevent memory leaks or dangling calls
    _unbindSystemMediaCallbacks();
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _unbindSystemMediaCallbacks() {
    systemMediaHandler.onPlayCallback = null;
    systemMediaHandler.onPauseCallback = null;
    systemMediaHandler.onSkipNextCallback = null;
    systemMediaHandler.onSkipPreviousCallback = null;
  }

  void _showPlaylistPanel({required bool autoPickFile}) {
    if (_isPanelOpen) {
      // Force the active panel instance to re-sync its track list
      playlistPanelKey?.currentState?.refresh();
      return;
    }

    _isPanelOpen = true;
    playlistPanelKey = GlobalKey<PlaylistPanelState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        return PlaylistPanel(
          key: playlistPanelKey, // Pass key here
          playlistManager: playlistManager,
          audioController: audioController,
          onPlayTrack: (String path) async {
            await loadSong(TrackMetadataItem.onlyPath(path));
            playlistManager.updateCurrentIndexWithPath(path);
            await audioController.setPlaying(true);
            playlistPanelKey?.currentState?.refresh();
            if (mounted) setState(() {});
          },
          autoPickFile: autoPickFile,
        );
      },
    ).then((_) {
      _isPanelOpen = false;
      playlistPanelKey = null;
    });
  }

  void _onTriggerPlayback() async {
    final song = await playlistManager.getCurrentMetadata();
    if (playlistManager.playlistPaths.isEmpty) {
      _showPlaylistPanel(autoPickFile: true);
    } else {
      if (!audioController.loaded) {
        await loadSong(song);
      }
      await audioController.setPlaying(!_isPlaying);
      playlistPanelKey?.currentState?.refresh();
    }
    setState(() {});
  }

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
              onPressed: () {
                audioController.loopType == LoopType.repeat
                    ? audioController.loopType = LoopType.loop
                    : audioController.loopType = LoopType.repeat;
                setState(() {});
              },
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
              onPressed: _onTriggerPlayback,
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
              onPressed: () => _showPlaylistPanel(autoPickFile: false),
              icon: const Icon(BootstrapIcons.list_nested),
              color: theme.textPrimary,
              iconSize: 20.0,
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Volume Controls Row
        Row(
          children: [
            Icon(
              audioController.volume == 0
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
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
