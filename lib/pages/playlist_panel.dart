import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../components/song_list/song_list_view.dart';
import '../controllers/audio_player_controller.dart';
import '../controllers/song_list/song_list_managers.dart';
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

  @override
  void initState() {
    super.initState();
    _initializePlaylistView();

    widget.audioController.addListener(_onControllerChanged);
    if (widget.autoPickFile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddAndPlay();
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

  Future<List<String>> _handleAdd() async {
    List<String> paths = await pickMultipleMusicFiles();
    if (paths.isEmpty) return paths;

    for (final path in paths) {
      await widget.playlistManager.addFileNextToCurrent(path);
    }

    _songListKey.currentState?.refresh();
    if (mounted) setState(() {});

    return paths;
  }

  Future<void> _handleAddAndPlay() async {
    final paths = await _handleAdd();
    if (paths.isNotEmpty) {
      widget.onPlayTrack(paths.first);
    }
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
    }
    _songListKey.currentState?.refresh();
  }

  Future<void> _handleShuffle() async {
    await widget.playlistManager.shufflePlaylist();
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
                        ),
                      ),
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
                'Next Up (${widget.playlistManager.length})',
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
                onPressed: _handleAdd,
                icon: Icon(Icons.add_rounded, color: theme.primaryColor),
                tooltip: 'Add Track',
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
          ),
        ],
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
}

GlobalKey<PlaylistPanelState>? playlistPanelKey;
