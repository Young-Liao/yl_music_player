import 'package:flutter/material.dart';
import 'package:yl_music_player/components/playback_controls.dart';
import 'package:yl_music_player/components/progress_bar.dart';
import 'package:yl_music_player/components/track_metadata.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/utils/playlist_manager.dart'
    hide TrackMetadataItem;
import 'package:yl_music_player/utils/track_stepper_mixin.dart';
import '../themes/theme_provider.dart';
import '../components/header_bar.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<StatefulWidget> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TrackStepperMixin {
  late final AudioPlayerController _audioController = AudioPlayerController(
    playbackCompleted: playCompleted,
  );
  final PlaylistManager _playlistManager = PlaylistManager(
    jsonFilePath: "./test_playlist.json",  // TODO: Change to Sqlite
  );

  @override
  // TODO: implement audioController
  AudioPlayerController get audioController => _audioController;

  @override
  // TODO: implement playlistManager
  PlaylistManager get playlistManager => _playlistManager;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _audioController,
      builder: (context, _) {
        final theme = CustomThemeProvider.of(context);
        return Scaffold(
          backgroundColor: theme.outerBackgroundColor,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 28.0,
                ),
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor,
                  borderRadius: BorderRadius.circular(theme.cardCornerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    HeaderBar(),
                    TrackMetadata(controller: _audioController),
                    Column(
                      children: [
                        ProgressBar(controller: _audioController),
                        PlaybackControls(
                          audioController: _audioController,
                          playlistManager: _playlistManager,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
