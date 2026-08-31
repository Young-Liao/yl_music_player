import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import 'package:yl_music_player/pages/playlist_panel.dart';

import '../components/file_manager/pieces/library_segmented_control.dart';
import '../components/file_manager/pieces/library_sidebar.dart';
import '../components/file_manager/windows/groups_window.dart';
import '../components/file_manager/windows/music_files_window.dart';
import '../components/file_manager/windows/playlists_window.dart';
import '../components/window/uploading_dialog.dart';
import '../controllers/song_list/item_selection_controller.dart';
import '../main.dart';
import '../navigation/app_router.dart';
import '../themes/theme_provider.dart';
import '../utils/file/file_picker.dart';

final fileManagerPageKey = GlobalKey<_FileManagerPageState>();

class FileManagerPage extends StatefulWidget {
  FileManagerPage({Key? key}) : super(key: key ?? fileManagerPageKey);

  @override
  State<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends State<FileManagerPage> {
  int _selectedLibraryIndex = 2;

  late final ItemSelectionController _selectionController;
  Completer<List<String>>? _selectionCompleter;
  bool _isSelectionMode = false;
  bool _isSubjectiveSelection = false;

  @override
  void initState() {
    super.initState();
    _selectionController = ItemSelectionController();
  }

  void _handleSelectIndex(int index) {
    setState(() {
      _selectedLibraryIndex = index;
    });
  }

  /// Global Upload handler usable across all library views
  Future<List<String>> handleUploadFiles() async {
    final List<String> paths = await pickMultipleMusicFiles();
    if (paths.isEmpty) return paths;

    if (mounted) {
      await UploadingDialog.show(
        context,
        luego: () async {
          for (int i = 0; i < paths.length; i++) {
            fileListManager.addFileAt(paths[i], i);
          }
          fileListManager.setSortOption(fileListManager.currentSort);
        },
        title: 'Uploading Files...',
        message: 'Adding ${paths.length} file(s) to root library.',
      );
    }

    if (mounted) setState(() {});

    return paths;
  }

  /// Upload a folder, recursively mirror its structure into groups, and import songs.
  Future<List<String>> handleUploadFolder() async {
    final String? folderPath = await pickMusicFolder();
    if (folderPath == null || folderPath.isEmpty) {
      return [];
    }

    final String folderName = p.basename(folderPath);
    final ValueNotifier<String> statusNotifier = ValueNotifier<String>(
      'Preparing folder import...',
    );

    try {
      if (mounted) {
        await UploadingDialog.show(
          context,
          luego: () async {
            final int createdGroupId = await groupManager
                .importFolderWithSubgroups(
              parentGroupName: folderName,
              rootFolderPath: folderPath,
              onProgress: (statusMessage, tracksProcessed) {
                statusNotifier.value =
                '$statusMessage\nTracks found: $tracksProcessed';
              },
            );
            debugPrint(
              '[FileManager] Successfully imported folder as group ID: $createdGroupId',
            );
          },
          title: 'Importing Folder...',
          message: 'Mirroring directory structure...',
        );
      }

      if (mounted) setState(() {});

      return [folderPath];
    } catch (e) {
      debugPrint('[FileManager] Error importing folder: $e');
      return [];
    } finally {
      statusNotifier.dispose();
    }
  }

  /// Triggers selection mode and awaits user confirmation.
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

    _selectionController.clearSelection();

    return _selectionCompleter!.future;
  }

  void _confirmSubjectiveSelection() {
    final List<String> selectedPaths = _selectionController.selectedIndices
        .map((index) => fileListManager.songPaths[index])
        .toList();

    setState(() {
      _isSelectionMode = false;
      _isSubjectiveSelection = false;
    });

    _selectionController.clearSelection();

    if (_selectionCompleter != null && !_selectionCompleter!.isCompleted) {
      _selectionCompleter!.complete(selectedPaths);
    }
  }

  void _cancelSelectionMode() {
    setState(() {
      _isSelectionMode = false;
    });

    _selectionController.clearSelection();

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
    _selectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return Stack(
      children: [
        if (isDesktop)
          Positioned.fill(
            child: DragToMoveArea(child: Container(color: Colors.transparent)),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 700;

            return Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: theme.outerBackgroundColor,
                ),
                if (isNarrow)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Center(
                      child: LibrarySegmentedControl(
                        selectedIndex: _selectedLibraryIndex,
                        onItemSelected: _handleSelectIndex,
                      ),
                    ),
                  ),
                Expanded(
                  child: Row(
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
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _handleToggleSelectionMode() {
    if (_isSelectionMode) {
      _cancelSelectionMode();
    } else {
      setState(() {
        _isSelectionMode = true;
        _isSubjectiveSelection = false;
      });
    }
  }

  Future<void> _handlePlayTrack(String path) async {
    playbackControlKey.currentState?.onPlayTrackAndCheckExistence(path);
    await Future.delayed(const Duration(milliseconds: 50));
    AppRouter.instance.goToRoute(AppRoute.player);
  }

  Future<void> _handleMoveToNextTrack(String path) async {
    final parentContext = Navigator.of(context, rootNavigator: true).context;

    playlistManager.addFileNextToCurrent(path);
    playlistPanelKey?.currentState?.refresh();
    await Future.delayed(const Duration(milliseconds: 50));
    AppRouter.instance.goToRoute(AppRoute.player);

    if (parentContext.mounted) {
      PlaylistPanel.show(
        parentContext,
        playlistManager: playlistManager,
        audioController: audioPlayerController,
        onPlayTrack: playbackControlKey.currentState?.onPlayTrack ?? (index) {},
      );
    }
  }

  Widget _buildMusicFilesWindow() {
    return MusicFilesWindow(
      key: musicFilesWindowKey,
      audioController: audioPlayerController,
      fileListManager: fileListManager,
      selectionController: _selectionController,
      isSelectionMode: _isSelectionMode,
      isSubjectiveSelection: _isSubjectiveSelection,
      onToggleSelectionMode: _handleToggleSelectionMode,
      onConfirmSubjectiveSelection: _confirmSubjectiveSelection,
      onUploadFilesPressed: handleUploadFiles,
      onUploadFolderPressed: handleUploadFolder,
      onPlayTrack: _handlePlayTrack,
      onMoveToNext: (int index) =>
          _handleMoveToNextTrack(fileListManager.songPaths[index]),
      onDelete: (int index) {},
    );
  }

  Widget _buildGroupsWindow() {
    return GroupsWindow(
      key: groupsWindowKey,
      audioController: audioPlayerController,
      selectionController: _selectionController,
      isSelectionMode: _isSelectionMode,
      isSubjectiveSelection: _isSubjectiveSelection,
      onToggleSelectionMode: _handleToggleSelectionMode,
      onConfirmSubjectiveSelection: _confirmSubjectiveSelection,
      onUploadFilesPressed: handleUploadFiles,
      onUploadFolderPressed: handleUploadFolder,
      onPlayTrack: _handlePlayTrack,
      onMoveToNext: _handleMoveToNextTrack,
    );
  }

  Widget _buildMainContent() {
    switch (_selectedLibraryIndex) {
      case 0:
        return _buildMusicFilesWindow();
      case 1:
        return const PlaylistsWindow();
      case 2:
        return _buildGroupsWindow();
      default:
        return _buildMusicFilesWindow();
    }
  }
}
