import 'package:flutter/material.dart';
import 'package:yl_music_player/components/lyrics_view.dart';
import 'package:yl_music_player/components/playback_controls.dart';
import 'package:yl_music_player/components/progress_bar.dart';
import 'package:yl_music_player/components/track_metadata.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/utils/lyrics_handler.dart';
import 'package:yl_music_player/utils/playlist_manager.dart'
    hide TrackMetadataItem;
import 'package:yl_music_player/utils/track_stepper_mixin.dart';
import '../themes/theme_provider.dart';
import '../components/header_bar.dart';

enum PlayerDisplayMode { metadata, lyrics }

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
    jsonFilePath: "./test_playlist.json", // TODO: Change to Sqlite
  );
  final LyricsHandler _lyricsHandler = LyricsHandler();

  PlayerDisplayMode _displayMode = PlayerDisplayMode.metadata;

  @override
  AudioPlayerController get audioController => _audioController;

  @override
  PlaylistManager get playlistManager => _playlistManager;

  @override
  LyricsHandler get lyricsHandler => _lyricsHandler;

  double _currentSliderValue = 0.0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  void _toggleDisplayMode() {
    setState(() {
      _displayMode = _displayMode == PlayerDisplayMode.metadata
          ? PlayerDisplayMode.lyrics
          : PlayerDisplayMode.metadata;
    });
  }

  GestureDetector _buildMetadataAndLyricsSwitcher() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleDisplayMode,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: _displayMode == PlayerDisplayMode.metadata
            ? TrackMetadata(
                key: const ValueKey('track_metadata'),
                controller: _audioController,
              )
            : LyricsView(
                key: const ValueKey('lyrics_view'),
                lyricsHandler: _lyricsHandler,
                currentPosition: Duration(seconds: _currentSliderValue.toInt()),
              ),
      ),
    );
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
                    // TrackMetadata(controller: _audioController),
                    // _buildMetadataAndLyricsSwitcher(),
                    Expanded(child: _buildMetadataAndLyricsSwitcher()),
                    Column(
                      children: [
                        ProgressBar(
                          controller: _audioController,
                          onSliderValueChanged: (value) {
                            if (mounted) {
                              setState(() {
                                _currentSliderValue = value;
                              });
                            }
                          },
                        ),
                        PlaybackControls(
                          audioController: _audioController,
                          playlistManager: _playlistManager,
                          lyricsManager: _lyricsHandler,
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
