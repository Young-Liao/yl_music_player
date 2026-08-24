import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../controllers/audio/audio_player_controller.dart';
import '../../controllers/song_list/song_list_managers.dart';
import '../../themes/app_theme_interface.dart';
import '../../themes/theme_provider.dart';
import '../../utils/data_structures/track_metadata_item.dart';
import '../animation/animated_equalizer.dart';

class SongListView extends StatefulWidget {
  final SongListManager songListManager;
  final AudioPlayerController audioController;
  final ValueChanged<String> onPlayTrack;
  final ScrollController scrollController;
  final Function(int index)? onMoveToNext;
  final Function(int index)? onDelete;

  final bool isSelectionMode;
  final Set<int> selectedIndices;
  final ValueChanged<int>? onToggleSelect;

  const SongListView({
    super.key,
    required this.songListManager,
    required this.audioController,
    required this.onPlayTrack,
    required this.scrollController,
    this.onMoveToNext,
    this.onDelete,
    this.isSelectionMode = false,
    this.selectedIndices = const {},
    this.onToggleSelect,
  });

  @override
  State<SongListView> createState() => SongListViewState();
}

class SongListViewState extends State<SongListView> {
  final List<TrackMetadataItem> _displayTracks = [];
  bool _isUpdatingWindow = false;

  @override
  void initState() {
    super.initState();
    _syncMetadataList();
  }

  void _syncMetadataList() {
    final paths = widget.songListManager.songPaths;
    _displayTracks.clear();

    for (int i = 0; i < paths.length; ++i) {
      final cached = widget.songListManager.getCachedMetadataAtIndex(i);
      _displayTracks.add(cached);
    }
  }

  void refresh() {
    if (mounted) {
      setState(() => _syncMetadataList());
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
      widget.songListManager
          .updateScrollWindow(visibleStart, visibleEnd)
          .then((_) {
        _isUpdatingWindow = false;
        if (mounted) {
          setState(() => _syncMetadataList());
        }
      });
    }
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _displayTracks.removeAt(oldIndex);
      _displayTracks.insert(newIndex, item);
    });

    await widget.songListManager.moveItem(
      oldIndex,
      newIndex < oldIndex ? newIndex : newIndex + 1,
    );
    _syncMetadataList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _handleScrollNotification(notification);
        return false;
      },
      child: CustomScrollView(
        controller: widget.scrollController,
        cacheExtent: 1000.0,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
            sliver: SliverReorderableList(
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
                    track.filePath == widget.audioController.currentPath;

                return ReorderableDelayedDragStartListener(
                  key: ValueKey('track_${index}_${track.filePath}'),
                  index: index,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10.0),
                    child: buildTrackTile(
                        context, theme, track, index, isActive),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTrackTile(
      BuildContext context,
      IAppTheme theme,
      TrackMetadataItem track,
      int index,
      bool isActive,
      ) {
    final isSelected = widget.selectedIndices.contains(index);

    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.cardCornerRadius - 4),
      // Disable slidable actions when in batch selection mode
      child: Slidable(
        enabled: !widget.isSelectionMode,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: [
            if (widget.onMoveToNext != null)
              CustomSlidableAction(
                onPressed: (_) => widget.onMoveToNext!(index),
                backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                foregroundColor: theme.primaryColor,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_add_rounded, size: 22),
                    SizedBox(height: 2),
                    Text('Next', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (widget.onDelete != null)
              CustomSlidableAction(
                onPressed: (_) => widget.onDelete!(index),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 22),
                    SizedBox(height: 2),
                    Text('Remove', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (widget.isSelectionMode) {
                widget.onToggleSelect?.call(index);
              } else {
                widget.onPlayTrack(track.filePath);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.primaryColor.withValues(alpha: 0.15)
                    : (isActive
                    ? theme.primaryColor.withValues(alpha: 0.1)
                    : theme.primaryColor.withValues(alpha: 0.03)),
              ),
              child: Row(
                children: [
                  // Show Checkbox if in selection mode, else show artwork
                  if (widget.isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      activeColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (_) => widget.onToggleSelect?.call(index),
                    ),
                    const SizedBox(width: 8),
                  ],
                  buildTrackArtwork(theme, track),
                  const SizedBox(width: 12),
                  Expanded(child: buildTrackInfo(theme, track, isActive)),
                  if (isActive && !widget.isSelectionMode) ...[
                    const SizedBox(width: 12),
                    AnimatedEqualizer(
                      color: theme.primaryColor,
                      size: 16,
                      isPlaying: widget.audioController.isPlaying,
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (!widget.isSelectionMode)
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

  Widget buildTrackArtwork(IAppTheme theme, TrackMetadataItem track) {
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

  Widget buildTrackInfo(
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
}