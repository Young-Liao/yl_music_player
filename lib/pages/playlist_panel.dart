import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../components/animated_equalizer.dart';
import '../themes/theme_provider.dart';

/// Data model representing a track in the playlist queue.
class PlaylistItem {
  final String id;
  final String title;
  final String artist;

  PlaylistItem({
    required this.id,
    required this.title,
    required this.artist,
  });
}

class PlaylistPanel extends StatefulWidget {
  final List<PlaylistItem> tracks;
  final String activeTrackId;
  final ValueChanged<PlaylistItem>? onTrackSelected;
  final ValueChanged<PlaylistItem>? onPlayNext;
  final ValueChanged<PlaylistItem>? onDelete;
  final VoidCallback? onShuffle;
  final bool isPlaying;

  const PlaylistPanel({
    super.key,
    required this.tracks,
    required this.activeTrackId,
    this.onTrackSelected,
    this.onPlayNext,
    this.onDelete,
    this.onShuffle,
    required this.isPlaying,
  });

  /// Displays the dynamic bottom sheet that snaps between 60% and 100% screen height.
  static Future<void> show(
      BuildContext context, {
        required List<PlaylistItem> tracks,
        required String activeTrackId,
        ValueChanged<PlaylistItem>? onTrackSelected,
        ValueChanged<PlaylistItem>? onPlayNext,
        ValueChanged<PlaylistItem>? onDelete,
        VoidCallback? onShuffle,
        required bool isPlaying,
      }) {
    return showModalBottomSheet(
      context: context,
      // Allows the sheet to expand beyond default height up to 100% height
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (context) {
        return PlaylistPanel(
          tracks: tracks,
          activeTrackId: activeTrackId,
          onTrackSelected: onTrackSelected,
          onPlayNext: onPlayNext,
          onDelete: onDelete,
          onShuffle: onShuffle,
          isPlaying: isPlaying,
        );
      },
    );
  }

  @override
  State<PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<PlaylistPanel> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    // DraggableScrollableSheet handles drag-to-resize and drag-down-to-dismiss behavior.
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        // Automatically dismiss modal when dragged below minChildSize threshold
        if (notification.extent <= 0.22) {
          Navigator.of(context).maybePop();
        }
        return true;
      },
      child: Stack(
        children: [
          // Invisible touch target covering the upper screen to catch barrier taps
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.65, // Starts at 65% window height
            minChildSize: 0.2,     // Dragging below 20% closes sheet
            maxChildSize: 1.0,     // Expands fully to 100% window height
            snap: true,            // Enforces Apple-like snap points
            snapSizes: const [0.65, 1.0], // Snap steps: half-screen or full-screen
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
                    // -------------------------------------------------------------
                    // Apple Style Drag Handle Bar (Pill Indicator: ----)
                    // -------------------------------------------------------------
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // Toggle between 0.65 and 1.0 on handle tap
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

                    // -------------------------------------------------------------
                    // Header Row (Next Up title & Shuffle button)
                    // -------------------------------------------------------------
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
                                'Next Up',
                                style: TextStyle(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onShuffle,
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
                    ),
                    const SizedBox(height: 12),

                    // -------------------------------------------------------------
                    // Playlist Items with Scroll Synchronization
                    // -------------------------------------------------------------
                    Expanded(
                      child: SlidableAutoCloseBehavior(
                        child: ListView.separated(
                          // Pass scrollController so sheet drag and list scroll operate together smoothly
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(20.0, 0.0, 20.0, 20.0),
                          itemCount: widget.tracks.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final track = widget.tracks[index];
                            final isActive = track.id == widget.activeTrackId;

                            // Slidable replaces Dismissible to reveal action buttons without auto-deleting
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(
                                theme.cardCornerRadius - 4,
                              ),
                              child: Slidable(
                                key: ValueKey(track.id),

                                // Actions shown when sliding left
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  extentRatio: 0.44, // Width ratio occupied by the 2 buttons
                                  children: [
                                    // 1. Play Next Action
                                    CustomSlidableAction(
                                      onPressed: (_) => widget.onPlayNext?.call(track),
                                      backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                                      foregroundColor: theme.primaryColor,
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.playlist_add_rounded, size: 22),
                                          SizedBox(height: 2),
                                          Text(
                                            'Next',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // 2. Remove Action
                                    CustomSlidableAction(
                                      onPressed: (_) => widget.onDelete?.call(track),
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 22),
                                          SizedBox(height: 2),
                                          Text(
                                            'Remove',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Card item view
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => widget.onTrackSelected?.call(track),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? theme.primaryColor.withValues(alpha: 0.1)
                                            : theme.primaryColor.withValues(alpha: 0.03),
                                        border: null, /*Border.all(
                                          color: isActive
                                              ? theme.primaryColor.withValues(alpha: 0.4)
                                              : Colors.transparent,
                                          width: 1.5,
                                        ), */
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  track.title,
                                                  style: TextStyle(
                                                    fontSize: 15.0,
                                                    fontWeight: isActive
                                                        ? FontWeight.w700
                                                        : FontWeight.w600,
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
                                            ),
                                          ),
                                          if (isActive) ...[
                                            const SizedBox(width: 12),
                                            AnimatedEqualizer(
                                              color: theme.primaryColor,
                                              size: 16,
                                              isPlaying: widget.isPlaying,
                                            ),
                                          ],
                                        ],
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
