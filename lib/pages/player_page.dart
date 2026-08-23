import 'package:flutter/material.dart';
import 'package:yl_music_player/components/lyrics_view.dart';
import 'package:yl_music_player/components/playback_controls.dart';
import 'package:yl_music_player/components/progress_bar.dart';
import 'package:yl_music_player/components/track_metadata.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/main.dart';
import 'package:yl_music_player/utils/lyrics_handler.dart';
import 'package:yl_music_player/utils/playlist_manager.dart';
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
  // Threshold breakpoint width for side-by-side layout
  static const double _kWideLayoutThreshold = 680.0;

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
    audioController.lyricsHandler = lyricsHandler;
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

  Widget _buildTrackMetadata() {
    return TrackMetadata(
      key: const ValueKey('track_metadata'),
      controller: _audioController,
    );
  }

  Widget _buildLyricsView() {
    return LyricsView(
      key: const ValueKey('lyrics_view'),
      lyricsHandler: _lyricsHandler,
      currentPosition: Duration(seconds: _currentSliderValue.toInt()),
      onSeekTo: (value) => audioController.seek(value),
    );
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
            ? _buildTrackMetadata()
            : _buildLyricsView(),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
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
    );
  }

  Widget _buildDynamicLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= _kWideLayoutThreshold;

        if (isWide) {
          // Expanded Desktop Layout (Side-by-Side)
          return Column(
            children: [
              HeaderBar(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
                    // Left Side: Metadata & Controls
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(child: Center(child: _buildTrackMetadata())),
                          _buildControlsSection(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Right Side: Lyrics
                    Expanded(flex: 6, child: _buildLyricsView()),
                  ],
                ),
              ),
            ],
          );
        } else {
          // Compact Portrait Layout (Single Panel Switcher)
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              HeaderBar(),
              Expanded(child: _buildMetadataAndLyricsSwitcher()),
              _buildControlsSection(),
            ],
          );
        }
      },
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
                child: _buildDynamicLayout(),
              ),
            ),
          ),
        );
      },
    );
  }
}
