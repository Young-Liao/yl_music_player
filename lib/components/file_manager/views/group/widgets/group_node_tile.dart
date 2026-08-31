import 'package:flutter/material.dart';

import '../../../../../themes/app_theme_interface.dart';
import '../../../../../utils/data_structures/group.dart';

class GroupNodeTile extends StatelessWidget {
  final GroupNode group;
  final int indentLevel;

  final bool isExpanded;
  final bool isSelected;
  final bool isSelectionMode;

  final IAppTheme theme;

  final VoidCallback onToggleExpand;
  final VoidCallback onNavigate;

  final ValueChanged<GroupNode>? onToggleSelect;

  final VoidCallback onAddSubgroup;
  final VoidCallback onMoveGroup;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  final Widget Function(
      GroupNode node,
      int level,
      ) buildChildGroup;

  final Widget Function(
      GroupedTrackMetadataItem track,
      int groupId,
      int level,
      ) buildChildTrack;

  final List<GroupedTrackMetadataItem> tracks;

  const GroupNodeTile({
    super.key,
    required this.group,
    required this.indentLevel,
    required this.isExpanded,
    required this.isSelected,
    required this.isSelectionMode,
    required this.theme,
    required this.onToggleExpand,
    required this.onNavigate,
    this.onToggleSelect,
    required this.onAddSubgroup,
    required this.onMoveGroup,
    required this.onRename,
    required this.onDelete,
    required this.buildChildGroup,
    required this.buildChildTrack,
    required this.tracks,
  });

  static const double _arrowWidth = 32.0;
  static const double _leadingGap = 8.0;
  static const double _iconWidth = 28.0;

  Widget _buildArrow() {
    return SizedBox(
      width: _arrowWidth,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
          maxWidth: 32,
          maxHeight: 32,
        ),
        visualDensity:
        VisualDensity.compact,
        icon: AnimatedRotation(
          turns: isExpanded ? 0.25 : 0.0,
          duration:
          const Duration(milliseconds: 150),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: theme.textSecondary,
          ),
        ),
        onPressed: onToggleExpand,
      ),
    );
  }

  Widget _buildFolder() {
    return SizedBox(
      width: _iconWidth,
      height: 32,
      child: Center(
        child: IconButton(
          padding: EdgeInsets.zero,
          constraints:
          const BoxConstraints(
            minWidth: 28,
            minHeight: 28,
            maxWidth: 28,
            maxHeight: 28,
          ),
          visualDensity:
          VisualDensity.compact,
          icon: Icon(
            Icons.folder_rounded,
            size: 20,
            color: theme.primaryColor,
          ),
          onPressed: isSelectionMode
              ? null
              : onNavigate,
        ),
      ),
    );
  }

  Widget _buildLeadingArea() {
    return SizedBox(
      width:
      _arrowWidth +
          _leadingGap +
          _iconWidth,
      height: 32,
      child: Row(
        children: [
          _buildArrow(),
          const SizedBox(
            width: _leadingGap,
          ),
          _buildFolder(),
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
        onSelected: (value) {
          switch (value) {
            case 'add_subgroup':
              onAddSubgroup();
              break;

            case 'move':
              onMoveGroup();
              break;

            case 'rename':
              onRename();
              break;

            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'add_subgroup',
            child: Text(
              'Add Sub-Group',
            ),
          ),
          const PopupMenuItem(
            value: 'move',
            child: Text(
              'Move Group',
            ),
          ),
          const PopupMenuItem(
            value: 'rename',
            child: Text(
              'Rename',
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'delete',
            child: Text(
              'Delete Group',
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
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
                ? () =>
                onToggleSelect?.call(
                  group,
                )
                : onNavigate,
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 6.0,
              ),
              child: Row(
                children: [
                  // Indentation applies to the complete
                  // leading structure.
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
                            onToggleSelect
                                ?.call(group),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                  ],

                  // arrow + folder
                  _buildLeadingArea(),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    flex: 5,
                    child: Text(
                      group.entity.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                        FontWeight.w600,
                        color:
                        theme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),

                  Expanded(
                    flex: 3,
                    child: Text(
                      '${group.totalTracks} tracks',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                        FontWeight.w500,
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
        ),

        if (isExpanded) ...[
          // Subgroups.
          ...group.subGroups.map(
                (sub) => buildChildGroup(
              sub,
              indentLevel + 1,
            ),
          ),

          // Tracks.
          ...tracks.map(
                (track) => buildChildTrack(
              track,
              group.entity.id,
              indentLevel + 1,
            ),
          ),
        ],
      ],
    );
  }
}
