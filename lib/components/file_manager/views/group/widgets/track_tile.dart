import 'package:flutter/material.dart';

import '../../../../../themes/app_theme_interface.dart';
import '../../../../../utils/data_structures/group.dart';

class TrackTile extends StatelessWidget {
  final GroupedTrackMetadataItem track;
  final int groupId;
  final int indentLevel;

  final bool isSelected;
  final bool isActive;
  final bool isSelectionMode;

  final IAppTheme theme;

  final ValueChanged<String> onPlayTrack;
  final ValueChanged<String>? onToggleTrackSelect;
  final Function(String trackPath)? onMoveToNext;
  final Function(String trackPath)? onDeleteTrack;

  final Future<void> Function(
      GroupedTrackMetadataItem track,
      int groupId,
      ) onMoveToGroup;

  const TrackTile({
    super.key,
    required this.track,
    required this.groupId,
    required this.indentLevel,
    required this.isSelected,
    required this.isActive,
    required this.isSelectionMode,
    required this.theme,
    required this.onPlayTrack,
    this.onToggleTrackSelect,
    this.onMoveToNext,
    this.onDeleteTrack,
    required this.onMoveToGroup,
  });

  static const double _arrowWidth = 32.0;
  static const double _leadingGap = 8.0;
  static const double _iconWidth = 28.0;

  Widget _buildArtwork() {
    if (track.compressedArtwork != null &&
        track.compressedArtwork!.isNotEmpty) {
      return ClipRRect(
        borderRadius:
        BorderRadius.circular(5),
        child: Image.memory(
          track.compressedArtwork!,
          width: 28,
          height: 28,
          fit: BoxFit.cover,
          errorBuilder:
              (_, _, _) => Icon(
            Icons.music_note_rounded,
            size: 18,
            color: isActive
                ? theme.primaryColor
                : theme.textMuted,
          ),
        ),
      );
    }

    return Icon(
      Icons.music_note_rounded,
      size: 18,
      color: isActive
          ? theme.primaryColor
          : theme.textMuted,
    );
  }

  Widget _buildLeadingArea() {
    // IMPORTANT:
    //
    // Group:
    //
    //   [arrow 32] [8] [folder 28]
    //
    // Track:
    //
    //   [empty 32] [8] [artwork 28]
    //
    // Therefore folder and artwork have exactly
    // the same horizontal position.

    return SizedBox(
      width:
      _arrowWidth +
          _leadingGap +
          _iconWidth,
      height: 32,
      child: Row(
        children: [
          const SizedBox(
            width: _arrowWidth,
          ),

          const SizedBox(
            width: _leadingGap,
          ),

          SizedBox(
            width: _iconWidth,
            height: _iconWidth,
            child: Center(
              child: _buildArtwork(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu() {
    return SizedBox(
      width: 32,
      child: PopupMenuButton<String>(
        enabled: !isSelectionMode,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: theme.textMuted,
        ),
        padding: EdgeInsets.zero,
        constraints:
        const BoxConstraints(),
        onSelected: (value) async {
          switch (value) {
            case 'play_now':
              onPlayTrack(track.filePath);
              break;

            case 'play_next':
              onMoveToNext?.call(
                track.filePath,
              );
              break;

            case 'move_to_group':
              await onMoveToGroup(
                track,
                groupId,
              );
              break;

            case 'delete':
              onDeleteTrack?.call(
                track.filePath,
              );
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'play_now',
            child: Text(
              'Play Now',
            ),
          ),
          const PopupMenuItem(
            value: 'play_next',
            child: Text(
              'Play Next',
            ),
          ),
          const PopupMenuItem(
            value: 'move_to_group',
            child: Text(
              'Move to Group...',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Text(
              'Delete File',
              style: TextStyle(
                color: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? theme.primaryColor
          .withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius:
      BorderRadius.circular(8),
      child: InkWell(
        borderRadius:
        BorderRadius.circular(8),
        overlayColor:
        WidgetStateProperty.resolveWith(
              (states) {
            if (states.contains(
              WidgetState.pressed,
            )) {
              return theme.primaryColor
                  .withValues(
                alpha: 0.12,
              );
            }

            if (states.contains(
              WidgetState.hovered,
            )) {
              return theme.primaryColor
                  .withValues(
                alpha: 0.055,
              );
            }

            return Colors.transparent;
          },
        ),
        onTap: isSelectionMode
            ? () => onToggleTrackSelect
            ?.call(track.filePath)
            : () => onPlayTrack(
          track.filePath,
        ),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          child: Row(
            children: [
              // Indentation.
              SizedBox(
                width:
                indentLevel * 20.0,
              ),

              if (isSelectionMode) ...[
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    value: isSelected,
                    activeColor:
                    theme.primaryColor,
                    onChanged: (_) =>
                        onToggleTrackSelect
                            ?.call(
                          track.filePath,
                        ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
              ],

              // Same leading slot as GroupNodeTile.
              _buildLeadingArea(),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Text(
                      track.title.isNotEmpty
                          ? track.title
                          : 'Unknown Title',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                        FontWeight.w600,
                        color: isActive
                            ? theme
                            .primaryColor
                            : theme
                            .textPrimary,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      track.artist,
                      style: TextStyle(
                        fontSize: 11.5,
                        color:
                        theme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 3,
                child: Text(
                  track.album.isNotEmpty
                      ? track.album
                      : '—',
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                    theme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                ),
              ),

              _buildMenu(),
            ],
          ),
        ),
      ),
    );
  }
}
