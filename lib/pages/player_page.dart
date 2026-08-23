import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yl_music_player/components/lyrics_view.dart';
import 'package:yl_music_player/main.dart';
import 'package:yl_music_player/utils/data_structures/track_metadata_item.dart';
import '../components/playback_controls.dart';
import 'package:yl_music_player/components/progress_bar.dart';
import 'package:yl_music_player/components/track_metadata.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/controllers/lyrics_handler.dart';
import 'package:yl_music_player/controllers/playlist_manager.dart';
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
  static const double _kWideLayoutThreshold = 680.0;

  late final AudioPlayerController _audioController = AudioPlayerController(
    playbackCompleted: playCompleted,
  );
  final PlaylistManager _playlistManager = PlaylistManager(db: dbStorage);
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
    playlistManager.loadPlaylistFromDb(
      onSongReady: (filePath) async {
        // Replace with your actual PlayerController or AudioPlayer instance
        await loadSong(TrackMetadataItem.onlyPath(filePath));
        debugPrint("Successfully loaded song at index ${playlistManager.currentIndex}: $filePath");
      },
    );
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
          return Column(
            children: [
              const HeaderBar(),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  children: [
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
                    Expanded(flex: 6, child: _buildLyricsView()),
                  ],
                ),
              ),
            ],
          );
        } else {
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const HeaderBar(),
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
        final isDesktop =
            !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

        return Scaffold(
          backgroundColor: theme.outerBackgroundColor,
          body: Stack(
            children: [
              // 1. Background layer: Full window DragToMoveArea for all outer gaps
              if (isDesktop)
                Positioned.fill(
                  child: DragToMoveArea(
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // 2. Foreground layer: Main Card Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: const EdgeInsets.only(
                      left: 24.0,
                      right: 24.0,
                      top: 8.0,
                      // Reduced so HeaderBar's top DragToMoveArea controls this area
                      bottom: 28.0,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardBackgroundColor,
                      borderRadius: BorderRadius.circular(
                        theme.cardCornerRadius,
                      ),
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
            ],
          ),
        );
      },
    );
  }
}
