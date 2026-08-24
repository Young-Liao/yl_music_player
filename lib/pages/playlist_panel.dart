import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:yl_music_player/main.dart';
import 'package:yl_music_player/navigation/app_router.dart';
import 'package:yl_music_player/pages/file_manager_page.dart';
import '../components/file_manager/music_files_window.dart';
import '../components/song_list/song_list_view.dart';
import '../controllers/audio/audio_player_controller.dart';
import '../controllers/song_list/playlist_manager.dart';
import '../themes/app_theme_interface.dart';
import '../themes/theme_provider.dart';
import '../utils/file/file_picker.dart';

class PlaylistPanel extends StatefulWidget {
  final PlaylistManager playlistManager;
  final AudioPlayerController audioController;
  final ValueChanged<String> onPlayTrack;
  final bool autoPickFile;

  const PlaylistPanel({
    super.key,
    required this.playlistManager,
    required this.audioController,
    required this.onPlayTrack,
    this.autoPickFile = false,
  });

  static Future<void> show(
      BuildContext context, {
        required PlaylistManager playlistManager,
        required AudioPlayerController audioController,
        required ValueChanged<String> onPlayTrack,
        bool autoPickFile = false,
      }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        return PlaylistPanel(
          playlistManager: playlistManager,
          audioController: audioController,
          onPlayTrack: onPlayTrack,
          autoPickFile: autoPickFile,
        );
      },
    );
  }

  @override
  State<PlaylistPanel> createState() => PlaylistPanelState();
}

class PlaylistPanelState extends State<PlaylistPanel> {
  final DraggableScrollableController _sheetController =
  DraggableScrollableController();
  final GlobalKey<SongListViewState> _songListKey = GlobalKey<SongListViewState>();

  bool _isLoading = true;
  bool _hasInitialScrolled = false;

  bool _isSelectionMode = false;
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _initializePlaylistView();

    widget.audioController.addListener(_onControllerChanged);
    if (widget.autoPickFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSystemPickAndPlay();
      });
    }
  }

  @override
  void dispose() {
    widget.audioController.removeListener(_onControllerChanged);
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _initializePlaylistView() async {
    setState(() => _isLoading = false);

    if (widget.playlistManager.length > 0) {
      final endIdx = (widget.playlistManager.length - 1).clamp(0, 20);
      widget.playlistManager.updateScrollWindow(0, endIdx).then((_) {
        _songListKey.currentState?.refresh();
      });
    }
  }

  void _onControllerChanged() {
    _songListKey.currentState?.refresh();
  }

  // Load from System Picker
  Future<List<String>> _handleSystemPick() async {
    List<String> paths = await pickMultipleMusicFiles();
    if (paths.isEmpty) return paths;

    for (final path in paths) {
      await widget.playlistManager.addFileNextToCurrent(path);
    }

    _songListKey.currentState?.refresh();
    if (mounted) setState(() {});

    return paths;
  }

  Future<void> _handleSystemPickAndPlay() async {
    final paths = await _handleSystemPick();
    if (paths.isNotEmpty) {
      widget.onPlayTrack(paths.first);
    }
  }

  // Load from Custom File Manager
  Future<void> _handleFileManagerPick() async {
    final parentContext = Navigator.of(context, rootNavigator: true).context;

    hide();

    // Placeholder mock response for demonstration:
    final List<String>? selectedPaths = await _showFileManagerModal(context);

    if (selectedPaths == null || selectedPaths.isEmpty) return;

    for (final path in selectedPaths) {
      await widget.playlistManager.addFileNextToCurrent(path);
    }

    _songListKey.currentState?.refresh();
    if (mounted) setState(() {});

    if (parentContext.mounted) {
      PlaylistPanel.show(
        parentContext,
        playlistManager: widget.playlistManager,
        audioController: widget.audioController,
        onPlayTrack: widget.onPlayTrack,
      );
    }
  }

  // Helper method to simulate launching your file manager if it's a route/dialog
  Future<List<String>?> _showFileManagerModal(BuildContext context) async {
    AppRouter.instance.goToPage(1);
    final ans = await fileManagerPageKey.currentState?.selectTracksInteractively();
    AppRouter.instance.goToPage(0);
    return ans;
  }

  Future<void> _handleMoveToNext(int index) async {
    final paths = widget.playlistManager.playlistPaths;
    if (index < 0 || index >= paths.length) return;

    final currentIdx = widget.playlistManager.currentIndex;
    final destinationIdx =
    paths.isEmpty ? 0 : (currentIdx + 1).clamp(0, paths.length);

    await widget.playlistManager.moveItem(index, destinationIdx);
    _songListKey.currentState?.refresh();
  }

  Future<void> _handleDelete(int index) async {
    final isCurrent = await widget.playlistManager.deleteItem(index);
    if (isCurrent) {
      widget.audioController.stop();
      lyricsHandler.loadFromFile(""); // TO EMPTY THE LYRICS
    }
    _songListKey.currentState?.refresh();
  }

  Future<void> _handleShuffle() async {
    await widget.playlistManager.shufflePlaylist();
    _songListKey.currentState?.refresh();
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIndices.clear();
    });
  }

  void _toggleSelectIndex(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _handleBatchDelete() async {
    if (_selectedIndices.isEmpty) return;

    final sortedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));  // To prevent influence!!!

    bool stoppedCurrent = false;
    for (final index in sortedIndices) {
      final isCurrent = await widget.playlistManager.deleteItem(index);
      if (isCurrent) {
        stoppedCurrent = true;
      }
    }

    if (stoppedCurrent) {
      widget.audioController.stop();
      lyricsHandler.loadFromFile(""); // TO EMPTY THE LYRICS
    }

    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });

    _songListKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        if (notification.extent <= 0.22) {
          Navigator.of(context).maybePop();
        }
        return true;
      },
      child: Stack(
        children: [
          _buildDismissBarrier(context),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.65,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.65, 0.9],
            builder: (context, scrollController) {
              if (!_hasInitialScrolled) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && scrollController.hasClients) {
                    _scrollToCurrentTrack(scrollController);
                    _hasInitialScrolled = true;
                  }
                });
              }

              return Container(
                decoration: BoxDecoration(
                  color: theme.cardBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24.0),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 25,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SlidableAutoCloseBehavior(
                  child: Column(
                    children: [
                      _buildDragHandle(theme),
                      _buildHeader(theme),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _isLoading
                            ? Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        )
                            : SongListView(
                          key: _songListKey,
                          songListManager: widget.playlistManager,
                          audioController: widget.audioController,
                          onPlayTrack: widget.onPlayTrack,
                          scrollController: scrollController,
                          onMoveToNext: _handleMoveToNext,
                          onDelete: _handleDelete,
                          isSelectionMode: _isSelectionMode,
                          selectedIndices: _selectedIndices,
                          onToggleSelect: _toggleSelectIndex,
                        ),
                      ),
                      if (_isSelectionMode)
                        _buildBatchActionFooter(theme),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDismissBarrier(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: const SizedBox.expand(),
      ),
    );
  }

  Widget _buildDragHandle(IAppTheme theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final target = _sheetController.size > 0.8 ? 0.65 : 0.9;
        _sheetController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: theme.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader(IAppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.playlist_play_rounded,
                color: theme.primaryColor,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text(
                _isSelectionMode
                    ? 'Selected (${_selectedIndices.length})'
                    : 'Next Up (${widget.playlistManager.length})',
                style: TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: _toggleSelectionMode,
                icon: Icon(
                  _isSelectionMode ? Icons.close_rounded : Icons.checklist_rounded,
                  color: theme.primaryColor,
                ),
                tooltip: _isSelectionMode ? 'Cancel Selection' : 'Select Tracks',
              ),
              const SizedBox(width: 4),
              if (!_isSelectionMode) ...[
                // Replaced single IconButton with PopupMenuButton for Add options
                PopupMenuButton<String>(
                  icon: Icon(Icons.add_rounded, color: theme.primaryColor),
                  tooltip: 'Add Track',
                  onSelected: (value) {
                    if (value == 'system') {
                      _handleSystemPick();
                    } else if (value == 'file_manager') {
                      _handleFileManagerPick();
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'system',
                      child: Row(
                        children: [
                          Icon(Icons.phone_android_rounded, size: 20, color: theme.primaryColor),
                          const SizedBox(width: 12),
                          const Text('Load from System'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'file_manager',
                      child: Row(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 20, color: theme.primaryColor),
                          const SizedBox(width: 12),
                          const Text('Load from File Manager'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: _handleShuffle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.textPrimary,
                    side: BorderSide(
                      color: theme.primaryColor.withValues(alpha: 0.2),
                    ),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 16,
                    color: theme.primaryColor,
                  ),
                  label: const Text(
                    'Shuffle',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatchActionFooter(IAppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.primaryColor.withValues(alpha: 0.1)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    if (_selectedIndices.length == widget.playlistManager.length) {
                      _selectedIndices.clear();
                    } else {
                      _selectedIndices.addAll(
                        List.generate(widget.playlistManager.length, (i) => i),
                      );
                    }
                  });
                },
                child: Text(
                  _selectedIndices.length == widget.playlistManager.length
                      ? 'Deselect All'
                      : 'Select All',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _selectedIndices.isEmpty ? null : _handleBatchDelete,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text('Delete (${_selectedIndices.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToCurrentTrack(ScrollController scrollController) {
    final currentIndex = widget.playlistManager.currentIndex;
    if (currentIndex < 0 || currentIndex >= widget.playlistManager.length) {
      return;
    }

    const double itemTotalHeight = 78.0;
    final double targetOffset = currentIndex * itemTotalHeight;

    if (scrollController.hasClients) {
      final double maxScroll = scrollController.position.maxScrollExtent;
      final double clampedOffset = targetOffset.clamp(0.0, maxScroll);

      scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void refresh() {
    _songListKey.currentState?.refresh();
  }

  void hide() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

GlobalKey<PlaylistPanelState>? playlistPanelKey;
