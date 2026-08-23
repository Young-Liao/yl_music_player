import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/utils/file/file_picker.dart';
import '../components/animated_equalizer.dart';
import '../themes/app_theme_interface.dart';
import '../themes/theme_provider.dart';
import '../utils/playlist_manager.dart';

class PlaylistPanel extends StatefulWidget {
  final PlaylistManager playlistManager;
  final AudioPlayerController audioController;
  final ValueChanged<String> onPlayTrack;
  final bool isPlaying;
  final bool autoPickFile;

  const PlaylistPanel({
    super.key,
    required this.playlistManager,
    required this.audioController,
    required this.onPlayTrack,
    required this.isPlaying,
    this.autoPickFile = false,
  });

  static Future<void> show(
    BuildContext context, {
    required PlaylistManager playlistManager,
    required AudioPlayerController audioController,
    required ValueChanged<String> onPlayTrack,
    required bool isPlaying,
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
          isPlaying: isPlaying,
          autoPickFile: autoPickFile,
        );
      },
    );
  }

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  final List<TrackMetadataItem> _displayTracks = [];
  bool _isLoading = true;
  bool _isUpdatingWindow = false;
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
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _initializePlaylistView() async {
    _syncMetadataList();
    setState(() => _isLoading = false);

    if (widget.playlistManager.length > 0) {
      final endIdx = (widget.playlistManager.length - 1).clamp(0, 20);
      widget.playlistManager.updateScrollWindow(0, endIdx).then((_) {
        if (mounted) {
          setState(() {
            _syncMetadataList();
          });
        }
      });
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        // Rebuilds tile highlight and equalizer state instantly
      });
    }
  }

  void _syncMetadataList() {
    final paths = widget.playlistManager.playlistPaths;
    _displayTracks.clear();

    for (int i = 0; i < paths.length; ++i) {
      final cached = widget.playlistManager.getCachedMetadataAtIndex(i);
      _displayTracks.add(cached);
    }
  }

  Future<List<String>> _handleAdd() async {
    List<String> paths = await pickMultipleMusicFiles();
    if (paths.isEmpty) return paths;

    for (final path in paths) {
      await widget.playlistManager.addFileNextToCurrent(path);
    }

    _syncMetadataList();
    if (mounted) setState(() {});

    return paths;
  }

  Future<void> _handleAddAndPlay() async {
    final paths = await _handleAdd();

    // Automatically play the first added song
    if (paths.isNotEmpty) {
      widget.onPlayTrack(paths.first);
    }
  }

  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      if (_isUpdatingWindow) return;

      final metrics = notification.metrics;
      const double itemTotalHeight = 74.0;

      final double adjustedPixels = metrics.pixels.clamp(0.0, double.infinity);

      final int visibleStart = (adjustedPixels / itemTotalHeight).floor();
      final int visibleEnd =
          ((adjustedPixels + metrics.viewportDimension) / itemTotalHeight)
              .ceil();

      _isUpdatingWindow = true;
      widget.playlistManager.updateScrollWindow(visibleStart, visibleEnd).then((
        _,
      ) {
        _isUpdatingWindow = false;
        if (mounted) {
          setState(() {
            _syncMetadataList();
          });
        }
      });
    }
  }

  Future<void> _handleMoveToNext(int index) async {
    final paths = widget.playlistManager.playlistPaths;
    if (index < 0 || index >= paths.length) return;

    final currentIdx = widget.playlistManager.currentIndex;
    final destinationIdx = paths.isEmpty
        ? 0
        : (currentIdx + 1).clamp(0, paths.length);

    await widget.playlistManager.moveItem(index, destinationIdx);
    setState(() => _syncMetadataList());
  }

  Future<void> _handleDelete(int index) async {
    final isCurrent = await widget.playlistManager.deleteItem(index);
    if (isCurrent) {
      widget.audioController.stop();
    }
    setState(() => _syncMetadataList());
  }

  Future<void> _handleShuffle() async {
    await widget.playlistManager.shufflePlaylist();
    setState(() => _syncMetadataList());
  }

  // Remove the artificial Future.delayed and sync state immediately
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    setState(() {
      // Perform optimistic local updates to prevent flash
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _displayTracks.removeAt(oldIndex);
      _displayTracks.insert(newIndex, item);
    });

    await widget.playlistManager.moveItem(
      oldIndex,
      newIndex < oldIndex ? newIndex : newIndex + 1,
    );
    _syncMetadataList();
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
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.65, 1.0],
            builder: (context, scrollController) {
              // Scroll to current index when loading...
              if (!_hasInitialScrolled) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && scrollController.hasClients) {
                    _scrollToCurrentTrack(scrollController);
                    _hasInitialScrolled = true; // Mark as complete
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
                      // Fixed Top Section: Drag handle and header stay pinned above scrolling content
                      _buildDragHandle(theme),
                      _buildHeader(theme),
                      const SizedBox(height: 12),

                      // Virtualized Dynamic Scroll Area
                      Expanded(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            _handleScrollNotification(notification);
                            return false;
                          },
                          child: CustomScrollView(
                            controller: scrollController,
                            cacheExtent: 1000.0,
                            slivers: [
                              _isLoading
                                  ? SliverFillRemaining(
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    )
                                  : _buildSliverTrackList(theme),
                            ],
                          ),
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
        final target = _sheetController.size > 0.8 ? 0.65 : 1.0;
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

  Widget _buildSliverTrackList(IAppTheme theme) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
      sliver: SliverReorderableList(
        // TODO: Fix Dragging
        itemCount: _displayTracks.length,
        onReorder: _handleReorder,
        proxyDecorator: (child, index, animation) {
          return Material(
            color: Colors.transparent,
            shadowColor: Colors.black26,
            elevation: 6,
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final track = _displayTracks[index];
          final isActive = track.filePath == widget.audioController.currentPath;

          return ReorderableDelayedDragStartListener(
            key: ValueKey('track_${index}_${track.filePath}'),
            index: index,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10.0),
              child: _buildTrackTile(context, theme, track, index, isActive),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackTile(
    BuildContext context,
    IAppTheme theme,
    TrackMetadataItem track,
    int index,
    bool isActive,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.cardCornerRadius - 4),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: [
            CustomSlidableAction(
              onPressed: (_) => _handleMoveToNext(index),
              backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
              foregroundColor: theme.primaryColor,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_add_rounded, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Next',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => _handleDelete(index),
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Remove',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onPlayTrack(track.filePath),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? theme.primaryColor.withValues(alpha: 0.1)
                    : theme.primaryColor.withValues(alpha: 0.03),
              ),
              child: Row(
                children: [
                  _buildTrackArtwork(theme, track),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTrackInfo(theme, track, isActive)),
                  if (isActive) ...[
                    const SizedBox(width: 12),
                    AnimatedEqualizer(
                      color: theme.primaryColor,
                      size: 16,
                      isPlaying: widget.isPlaying,
                    ),
                  ],
                  const SizedBox(width: 8),
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_handle_rounded,
                      color: theme.textSecondary.withValues(alpha: 0.4),
                      size: 20,
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

  /// Artwork widget using AnimatedSwitcher for smooth transitions when artwork loads.
  Widget _buildTrackArtwork(IAppTheme theme, TrackMetadataItem track) {
    final artworkBytes = track.compressedArtwork;
    const artworkSize = 22.0;
    const borderRadius = 8.0;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeIn,
          switchOutCurve: Curves.easeOut,
          child: artworkBytes == null
              ? Icon(
                  Icons.music_note_rounded,
                  key: const ValueKey('placeholder_icon'),
                  color: theme.primaryColor,
                  size: artworkSize,
                )
              : Image.memory(
                  artworkBytes,
                  key: ValueKey(track.filePath),
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                  width: 44,
                  height: 44,
                ),
        ),
      ),
    );
  }

  Widget _buildTrackInfo(
    IAppTheme theme,
    TrackMetadataItem track,
    bool isActive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          style: TextStyle(
            fontSize: 15.0,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            color: theme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          track.artist,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w500,
            color: theme.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _scrollToCurrentTrack(ScrollController scrollController) {
    debugPrint("SCROLLING TO CURRENT TRACK");
    final currentIndex = widget.playlistManager.currentIndex;
    if (currentIndex < 0 || currentIndex >= widget.playlistManager.length) return;

    const double itemTotalHeight = 78.0; // 68px item + 10px margin
    final double targetOffset = currentIndex * itemTotalHeight;

    // Ensure scroll view is attached before attempting to animate/jump
    if (scrollController.hasClients) {
      // Clamp to valid max scroll extent to avoid overscroll errors
      final double maxScroll = scrollController.position.maxScrollExtent;
      final double clampedOffset = targetOffset.clamp(0.0, maxScroll);
      debugPrint("Initially Scrolling... target: $clampedOffset of $maxScroll");

      scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
}
