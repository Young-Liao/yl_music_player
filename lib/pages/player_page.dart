import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yl_music_player/components/lyrics_view.dart';
import 'package:yl_music_player/utils/data_structures/track_metadata_item.dart';
import 'package:yl_music_player/utils/link_service.dart';
import '../components/playback_controls.dart';
import 'package:yl_music_player/components/progress_bar.dart';
import 'package:yl_music_player/components/track_metadata.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/controllers/lyrics_handler.dart';
import 'package:yl_music_player/controllers/song_list/song_list_managers.dart';
import 'package:yl_music_player/utils/track_stepper_mixin.dart';
import '../themes/app_theme_interface.dart';
import '../themes/theme_provider.dart';
import '../components/header_bar.dart';

enum PlayerDisplayMode { metadata, lyrics }

class PlayerPage extends StatefulWidget {
  final PlaylistManager playlistManager;
  final LyricsHandler lyricsHandler;

  const PlayerPage({
    super.key,
    required this.playlistManager,
    required this.lyricsHandler,
  });

  @override
  State<StatefulWidget> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with TrackStepperMixin {
  static const double _kWideLayoutThreshold = 680.0;

  static const _supportedAudioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
  };

  late final AudioPlayerController _audioController;

  PlayerDisplayMode _displayMode = PlayerDisplayMode.metadata;
  bool _isDragging = false;
  double _currentSliderValue = 0.0;

  @override
  AudioPlayerController get audioController => _audioController;

  @override
  PlaylistManager get playlistManager => widget.playlistManager;

  @override
  LyricsHandler get lyricsHandler => widget.lyricsHandler;

  @override
  void initState() {
    super.initState();
    _audioController = AudioPlayerController(
      playbackCompleted: () => playCompleted(),
    );

    audioController.lyricsHandler = lyricsHandler;
    playlistManager
        .loadListFromDb(
      onSongReady: (filePath) async {
        await loadSong(TrackMetadataItem.onlyPath(filePath));
        debugPrint(
          "Successfully loaded song at index ${playlistManager.currentIndex}: $filePath",
        );
      },
    )
        .then((_) => LinkService.instance.releaseCache());
  }

  @override
  void dispose() {
    _audioController.dispose();
    super.dispose();
  }

  /// Check if file extension matches supported audio formats
  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _supportedAudioExtensions.any(lower.endsWith);
  }

  /// Process audio files from either Drag & Drop or "Open With"
  void _handleIncomingFiles(List<String> rawPaths) {
    for (final path in rawPaths) {
      if (_isAudioFile(path)) {
        LinkService.instance.addLink(path);
      }
    }
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
      lyricsHandler: lyricsHandler,
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
          playlistManager: playlistManager,
          lyricsManager: lyricsHandler,
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

  Widget _buildDragOverlay(IAppTheme activeTheme) {
    return Positioned.fill(
      child: Container(
        color: activeTheme.themeData.primaryColor.withOpacity(0.2),
        child: Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.library_music_rounded, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Drop audio files to play',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        final isDesktop =
            !kIsWeb &&
                (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

        return DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (details) {
            setState(() => _isDragging = false);
            final paths = details.files
                .map((XFile file) => file.path)
                .toList();
            _handleIncomingFiles(paths);
          },
          child: Scaffold(
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

                // 3. Drag overlay layer
                if (_isDragging) _buildDragOverlay(theme),
              ],
            ),
          ),
        );
      },
    );
  }
}
