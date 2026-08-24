import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yl_music_player/main.dart';
import 'package:yl_music_player/navigation/app_router.dart';
import '../components/file_manager/groups_window.dart';
import '../components/file_manager/library_sidebar.dart';
import '../components/file_manager/music_files_window.dart';
import '../components/file_manager/playlists_window.dart';
import '../components/window/header_bar.dart';
import '../controllers/audio/audio_player_controller.dart';
import '../controllers/song_list/file_list_manager.dart';
import '../themes/theme_provider.dart';

class FileManagerPage extends StatefulWidget {
  final AudioPlayerController audioController;
  final FileListManager fileListManager;

  const FileManagerPage({
    super.key,
    required this.audioController,
    required this.fileListManager,
  });

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  int _selectedLibraryIndex = 0;
  bool _isDrawerOpen = false;

  void _handleSelectIndex(int index) {
    setState(() {
      _selectedLibraryIndex = index;
      _isDrawerOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return Scaffold(
      backgroundColor: theme.outerBackgroundColor,
      body: Stack(
        children: [
          if (isDesktop)
            Positioned.fill(
              child: DragToMoveArea(
                child: Container(color: Colors.transparent),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                clipBehavior: Clip.antiAlias,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isNarrow = constraints.maxWidth < 700;

                    return Column(
                      children: [
                        // Top Global App Header
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: HeaderBar(),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.outerBackgroundColor,
                        ),

                        // Workspace Area
                        Expanded(
                          child: Stack(
                            children: [
                              // Main Layout Row
                              Row(
                                children: [
                                  if (!isNarrow) ...[
                                    SizedBox(
                                      width: 200,
                                      child: LibrarySidebar(
                                        selectedIndex: _selectedLibraryIndex,
                                        onItemSelected: _handleSelectIndex,
                                        theme: theme,
                                      ),
                                    ),
                                    VerticalDivider(
                                      width: 1,
                                      thickness: 1,
                                      color: theme.outerBackgroundColor,
                                    ),
                                  ],
                                  Expanded(child: _buildMainContent()),
                                ],
                              ),

                              // Floating Menu Button (Top-Left of Content Area when narrow)
                              if (isNarrow)
                                Positioned(
                                  left: 12.0,
                                  top: 14.0,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: IconButton(
                                      icon: Icon(
                                        BootstrapIcons.list,
                                        size: 20.0,
                                        color: theme.textPrimary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isDrawerOpen = !_isDrawerOpen;
                                        });
                                      },
                                      splashRadius: 20,
                                      tooltip: 'Toggle Sidebar',
                                    ),
                                  ),
                                ),

                              // Floating Backdrop (Close on tap outside)
                              if (isNarrow && _isDrawerOpen)
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isDrawerOpen = false;
                                    });
                                  },
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.2),
                                  ),
                                ),

                              // Sliding Sidebar Overlay
                              if (isNarrow)
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  left: _isDrawerOpen ? 0 : -220,
                                  top: 0,
                                  bottom: 0,
                                  width: 200,
                                  child: Material(
                                    color: theme.cardBackgroundColor,
                                    elevation: 8,
                                    child: LibrarySidebar(
                                      selectedIndex: _selectedLibraryIndex,
                                      onItemSelected: _handleSelectIndex,
                                      theme: theme,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicFilesWindow() {
    return MusicFilesWindow(
      audioController: widget.audioController,
      fileListManager: widget.fileListManager,
      onPlayTrack: (path) async {
        // playbackControlKey.currentState?.onPlayTrack(path);
        playbackControlKey.currentState?.onPlayTrackAndCheckExistence(path);
        await Future.delayed(const Duration(milliseconds: 50));
        AppRouter.instance.goToPage(0); // Go to Player
      },
    );
  }

  Widget _buildMainContent() {
    switch (_selectedLibraryIndex) {
      case 0:
        return _buildMusicFilesWindow();
      case 1:
        return const PlaylistsWindow();
      case 2:
        return const GroupsWindow();
      default:
        return _buildMusicFilesWindow();
    }
  }
}
