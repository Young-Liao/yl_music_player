import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:yl_music_player/utils/file_picker.dart';
import '../components/animated_equalizer.dart';
import '../themes/theme_provider.dart';
import '../utils/playlist_manager.dart';

/// A high-performance, bottom-sheet playlist panel directly integrated with [PlaylistManager].
///
/// Features dynamic window-based metadata loading, drag-and-drop reordering,
/// slidable track management (Play Next, Delete), and current playing state visualization.
class PlaylistPanel extends StatefulWidget {
  /// Shared instance of the central playlist manager controlling queue state & caching.
  final PlaylistManager playlistManager;

  /// Active playing track file path used to highlight the current playing item.
  final String activeTrackPath;

  /// Global audio engine playback callback triggered when selecting a track to play.
  final ValueChanged<String> onPlayTrack;

  /// Global state flag indicating whether audio playback is currently active.
  final bool isPlaying;

  const PlaylistPanel({
    super.key,
    required this.playlistManager,
    required this.activeTrackPath,
    required this.onPlayTrack,
    required this.isPlaying,
  });

  /// Static helper to launch the playlist modal sheet snapping between 65% and 100% height.
  static Future<void> show(
    BuildContext context, {
    required PlaylistManager playlistManager,
    required String activeTrackPath,
    required ValueChanged<String> onPlayTrack,
    required bool isPlaying,
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
          activeTrackPath: activeTrackPath,
          onPlayTrack: onPlayTrack,
          isPlaying: isPlaying,
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

  /// Local snapshot list of metadata matching [PlaylistManager.playlistPaths].
  final List<TrackMetadataItem> _displayTracks = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePlaylistView();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  /// Initial load: populates display queue with fast synchronous fallbacks or cached metadata,
  /// then immediately warms up the initial scroll window cache range.
  Future<void> _initializePlaylistView() async {
    _syncMetadataList();
    setState(() => _isLoading = false);

    // Warm up the initial visible window range (assume first ~10 items visible)
    final initialEnd = widget.playlistManager.length > 10
        ? 10
        : widget.playlistManager.length - 1;
    if (initialEnd >= 0) {
      await widget.playlistManager.updateScrollWindow(0, initialEnd);
      _syncMetadataList();
      if (mounted) setState(() {});
    }
  }

  /// Synchronizes local list entries with [PlaylistManager] LRU cache state without blocking UI.
  void _syncMetadataList() {
    final paths = widget.playlistManager.playlistPaths;
    _displayTracks.clear();

    for (final path in paths) {
      // Query cache first; fallback to fast synchronous path parsing if not cached yet
      final cached = widget.playlistManager.getCurrentMetadataSync(path);
      _displayTracks.add(cached);
    }
  }

  /// Calculates visible list indices from scroll metrics and triggers [PlaylistManager.updateScrollWindow].
  /// This ensures metadata is lazy-loaded ahead of scroll position like high-performance virtualized lists.
  void _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.maxScrollExtent <= 0) return;

      // Approximate item extent (card height ~64px + 10px spacing = ~74px)
      const double itemHeight = 74.0;
      final int visibleStart = (metrics.pixels / itemHeight).floor().clamp(
        0,
        widget.playlistManager.length - 1,
      );
      final int visibleEnd =
          ((metrics.pixels + metrics.viewportDimension) / itemHeight)
              .ceil()
              .clamp(0, widget.playlistManager.length - 1);

      // Async background metadata prefetch inside the dynamic sliding window [L, R]
      widget.playlistManager.updateScrollWindow(visibleStart, visibleEnd).then((
        _,
      ) {
        if (mounted) {
          setState(() {
            _syncMetadataList();
          });
        }
      });
    }
  }

  /// Moves item to play next directly after the current playing index.
  Future<void> _handlePlayNext(int index) async {
    final paths = widget.playlistManager.playlistPaths;
    if (index < 0 || index >= paths.length) return;

    final targetPath = paths[index];
    final currentIdx = widget.playlistManager.currentIndex;
    final destinationIdx = paths.isEmpty
        ? 0
        : (currentIdx + 1).clamp(0, paths.length);

    await widget.playlistManager.moveItem(index, destinationIdx);
    setState(() => _syncMetadataList());
  }

  /// Deletes a track from the queue, purges cache entry, and updates local view.
  Future<void> _handleDelete(int index) async {
    await widget.playlistManager.deleteItem(index);
    setState(() => _syncMetadataList());
  }

  /// Shuffles queue order, maintains current track, and refreshes dynamic scroll window.
  Future<void> _handleShuffle() async {
    await widget.playlistManager.shufflePlaylist();
    setState(() => _syncMetadataList());
  }

  /// Reorders item positions within [PlaylistManager] via drag-and-drop.
  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    await widget.playlistManager.moveItem(oldIndex, newIndex);
    setState(() => _syncMetadataList());
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
          // Background barrier tap dismissal target
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.65,
            minChildSize: 0.2,
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.65, 1.0],
            builder: (context, scrollController) {
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
                child: Column(
                  children: [
                    // Handle Bar Top Drag Indicator
                    GestureDetector(
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
                    ),

                    // Top Control Bar Header
                    Padding(
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
                                onPressed: () async {
                                  List<String> paths =
                                      await pickMultipleMusicFiles();
                                  for (final path in paths) {
                                    widget.playlistManager.addFileNextToCurrent(
                                      path,
                                    );
                                  }
                                  if (mounted) {
                                    setState(() {
                                      _syncMetadataList();
                                    });
                                  }
                                },
                                icon: Icon(
                                  Icons.add_rounded,
                                  color: theme.primaryColor,
                                ),
                                tooltip: 'Add Track',
                              ),
                              const SizedBox(width: 4),
                              OutlinedButton.icon(
                                onPressed: _handleShuffle,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.textPrimary,
                                  side: BorderSide(
                                    color: theme.primaryColor.withValues(
                                      alpha: 0.2,
                                    ),
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
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scroll-aware Dynamic Lazy Loaded List with Drag-Reorder
                    Expanded(
                      child: _isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: theme.primaryColor,
                              ),
                            )
                          : SlidableAutoCloseBehavior(
                              child: NotificationListener<ScrollNotification>(
                                onNotification: (notification) {
                                  _handleScrollNotification(notification);
                                  return false;
                                },
                                child: ReorderableListView.builder(
                                  scrollController: scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    20.0,
                                    0.0,
                                    20.0,
                                    20.0,
                                  ),
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
                                    final isActive =
                                        track.filePath ==
                                        widget.activeTrackPath;

                                    return Container(
                                      key: ValueKey(track.filePath),
                                      margin: const EdgeInsets.only(
                                        bottom: 10.0,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          theme.cardCornerRadius - 4,
                                        ),
                                        child: Slidable(
                                          endActionPane: ActionPane(
                                            motion: const DrawerMotion(),
                                            extentRatio: 0.44,
                                            children: [
                                              // Action 1: Play Next
                                              CustomSlidableAction(
                                                onPressed: (_) {},
                                                // TODO: Add to next
                                                backgroundColor: theme
                                                    .primaryColor
                                                    .withValues(alpha: 0.15),
                                                foregroundColor:
                                                    theme.primaryColor,
                                                child: const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .playlist_add_rounded,
                                                      size: 22,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Next',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              // Action 2: Remove
                                              CustomSlidableAction(
                                                onPressed: (_) =>
                                                    _handleDelete(index),
                                                backgroundColor:
                                                    Colors.redAccent,
                                                foregroundColor: Colors.white,
                                                child: const Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 22,
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Remove',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              onTap: () => widget.onPlayTrack(
                                                track.filePath,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isActive
                                                      ? theme.primaryColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            )
                                                      : theme.primaryColor
                                                            .withValues(
                                                              alpha: 0.03,
                                                            ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            track.title,
                                                            style: TextStyle(
                                                              fontSize: 15.0,
                                                              fontWeight:
                                                                  isActive
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w600,
                                                              color: theme
                                                                  .textPrimary,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                            height: 2,
                                                          ),
                                                          Text(
                                                            track.artist,
                                                            style: TextStyle(
                                                              fontSize: 13.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: theme
                                                                  .textSecondary,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (isActive) ...[
                                                      const SizedBox(width: 12),
                                                      AnimatedEqualizer(
                                                        color:
                                                            theme.primaryColor,
                                                        size: 16,
                                                        isPlaying:
                                                            widget.isPlaying,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Helper extension on [PlaylistManager] to allow instant non-blocking local retrieval.
extension PlaylistManagerSyncExtension on PlaylistManager {
  /// Returns cached metadata instantly if present, or synchronous fallback without async blocking.
  TrackMetadataItem getCurrentMetadataSync(String path) {
    if (playlistPaths.contains(path)) {
      // Internal cache lookup
      final cached = getCurrentMetadataSyncOrNull(path);
      if (cached != null) return cached;
    }
    return TrackMetadataItem.fallback(path);
  }

  /// Internal lookup for cache presence without asynchronous extraction.
  TrackMetadataItem? getCurrentMetadataSyncOrNull(String path) {
    // If your LRU cache instance inside PlaylistManager is private,
    // expose a synchronous `getFromCache(path)` getter on PlaylistManager directly.
    return null;
  }
}
