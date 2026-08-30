import 'dart:async';
import 'dart:io';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../components/file_manager/groups_window.dart';
import '../components/file_manager/library_sidebar.dart';
import '../components/file_manager/music_files_window.dart';
import '../components/file_manager/playlists_window.dart';
import '../components/window/header_bar.dart';
import '../controllers/audio/audio_player_controller.dart';
import '../controllers/song_list/file_list_manager.dart';
import '../main.dart';
import '../navigation/app_router.dart';
import '../themes/theme_provider.dart';

final fileManagerPageKey = GlobalKey<_FileManagerPageState>();

class FileManagerPage extends StatefulWidget {
  final AudioPlayerController audioController;
  final FileListManager fileListManager;

  FileManagerPage({
    Key? key,
    required this.audioController,
    required this.fileListManager,
  }) : super(key: key ?? fileManagerPageKey);

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  int _selectedLibraryIndex = 0;
  bool _isDrawerOpen = false;

  Completer<List<String>>? _selectionCompleter;
  bool _isSelectionMode = false;
  bool _isSubjectiveSelection = false;

  @override
  void initState() {
    super.initState();
  }

  void _handleSelectIndex(int index) {
    setState(() {
      _selectedLibraryIndex = index;
      _isDrawerOpen = false;
    });
  }

  /// Triggers selection mode and awaits user confirmation.
  /// Returns a list of file paths selected by the user.
  Future<List<String>> selectTracksInteractively() async {
    if (_selectionCompleter != null && !_selectionCompleter!.isCompleted) {
      _selectionCompleter!.complete([]);
    }

    _selectionCompleter = Completer<List<String>>();

    setState(() {
      _selectedLibraryIndex = 0; // Switch to Music Files view
      _isSelectionMode = true;
      _isSubjectiveSelection = true;
    });

    musicFilesWindowKey.currentState?.clearSelection();

    return _selectionCompleter!.future;
  }

  void _confirmSubjectiveSelection() {
    final selectedIndices =
        musicFilesWindowKey.currentState?.selectedIndices ?? {};

    final List<String> selectedPaths = selectedIndices.map((index) {
      return widget.fileListManager.songPaths[index];
    }).toList();

    setState(() {
      _isSelectionMode = false;
      _isSubjectiveSelection = false;
    });

    musicFilesWindowKey.currentState?.clearSelection();

    if (_selectionCompleter != null && !_selectionCompleter!.isCompleted) {
      _selectionCompleter!.complete(selectedPaths);
    }
  }

  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
    });

    musicFilesWindowKey.currentState?.clearSelection();

    if (_isSubjectiveSelection) {
      _isSubjectiveSelection = false;
      if (_selectionCompleter != null && !_selectionCompleter!.isCompleted) {
        _selectionCompleter!.complete([]);
      }
    }
  }

  @override
  void dispose() {
    if (_selectionCompleter != null && !_selectionCompleter!.isCompleted) {
      _selectionCompleter!.complete([]);
    }
    super.dispose();
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
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: HeaderBar(
                            onTransferServiceChanged: (value) {
                              if (mounted) {
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.outerBackgroundColor,
                        ),
                        Expanded(
                          child: Stack(
                            children: [
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
                              if (isNarrow)
                                Positioned(
                                  left: 20.0,
                                  top: -8.0,
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
      key: musicFilesWindowKey,
      audioController: widget.audioController,
      fileListManager: widget.fileListManager,
      isSelectionMode: _isSelectionMode,
      isSubjectiveSelection: _isSubjectiveSelection,
      onToggleSelectionMode: () {
        if (_isSelectionMode) {
          _cancelSelectionMode();
        } else {
          setState(() {
            _isSelectionMode = true;
            _isSubjectiveSelection = false;
          });
        }
      },
      onConfirmSubjectiveSelection: _confirmSubjectiveSelection,
      onPlayTrack: (path) async {
        playbackControlKey.currentState?.onPlayTrackAndCheckExistence(path);
        await Future.delayed(const Duration(milliseconds: 50));
        AppRouter.instance.goToPage(0);
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
