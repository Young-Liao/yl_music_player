import 'package:flutter/material.dart';

import '../../controllers/audio/audio_player_controller.dart';
import '../../controllers/song_list/file_list_manager.dart';
import '../../themes/app_theme_interface.dart';
import '../../themes/theme_provider.dart';
import '../../utils/data_structures/track_metadata_item.dart';
import '../song_list/song_list_view.dart';

class FileListView extends StatefulWidget {
  final FileListManager fileListManager;
  final AudioPlayerController audioController;
  final ValueChanged<String> onPlayTrack;
  final ScrollController scrollController;
  final Function(int index)? onMoveToNext;
  final Function(int index)? onDelete;

  final bool isSelectionMode;
  final Set<int> selectedIndices;
  final ValueChanged<int>? onToggleSelect;
  final bool areAllSelected;
  final VoidCallback? onToggleSelectAll;

  const FileListView({
    super.key,
    required this.fileListManager,
    required this.audioController,
    required this.onPlayTrack,
    required this.scrollController,
    this.onMoveToNext,
    this.onDelete,
    this.isSelectionMode = false,
    this.selectedIndices = const {},
    this.onToggleSelect,
    required this.areAllSelected,
    required this.onToggleSelectAll,
  });

  @override
  State<FileListView> createState() => _FileListViewState();
}

class _FileListViewState extends State<FileListView> {
  final ScrollController _horizontalScrollController = ScrollController();
  // Average height of each ListView row in pixels
  static const double _itemExtent = 56.0;
  bool _isFetchingWindow = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollChanged);
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _onScrollChanged() {
    _checkAndLoadVisibleWindow();
  }

  void _checkAndLoadVisibleWindow() {
    if (_isFetchingWindow || !widget.scrollController.hasClients) return;

    final double offset = widget.scrollController.offset;
    final double viewportHeight = widget.scrollController.position.viewportDimension;

    // Calculate window bounds with a small overscan buffer
    final int windowL = (offset / _itemExtent).floor() - 2;
    final int windowR = ((offset + viewportHeight) / _itemExtent).ceil() + 2;

    _isFetchingWindow = true;

    widget.fileListManager.ensureWindowCached(windowL, windowR).then((hasUpdated) {
      _isFetchingWindow = false;
      if (mounted && hasUpdated) {
        setState(() {}); // Rebuild UI with newly populated cache metadata
      }
    }).catchError((_) {
      _isFetchingWindow = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadVisibleWindow();
    });

    final theme = CustomThemeProvider.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Responsive Header Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 380;

              final titleWidget = Text(
                'Music Files Items',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              );

              final sortWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sort by: ',
                    style: TextStyle(
                      fontSize: 13.0,
                      color: theme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  MenuAnchor(
                    style: MenuStyle(
                      elevation: const WidgetStatePropertyAll(4),
                      shadowColor:
                      const WidgetStatePropertyAll(Colors.black12),
                      surfaceTintColor: const WidgetStatePropertyAll(
                        Colors.transparent,
                      ),
                      backgroundColor: WidgetStatePropertyAll(
                        theme.cardBackgroundColor,
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(vertical: 4),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                    menuChildren: FileListSortOption.values
                        .map((FileListSortOption option) {
                      final isSelected =
                          option == widget.fileListManager.currentSort;
                      return MenuItemButton(
                        style: ButtonStyle(
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                              ) {
                            if (states.contains(WidgetState.hovered) ||
                                isSelected) {
                              return theme.outerBackgroundColor.withValues(
                                alpha: 0.5,
                              );
                            }
                            return Colors.transparent;
                          }),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 2.0,
                            ),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            widget.fileListManager.setSortOption(option);
                          });
                        },
                        child: Container(
                          width: 100,
                          height: 32,
                          padding:
                          const EdgeInsets.symmetric(horizontal: 10.0),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          child: Text(
                            option.label,
                            style: TextStyle(
                              fontSize: 13.0,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    builder: (
                        BuildContext context,
                        MenuController controller,
                        Widget? child,
                        ) {
                      return InkWell(
                        onTap: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        borderRadius: BorderRadius.circular(8.0),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.outerBackgroundColor,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            color: theme.cardBackgroundColor,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.fileListManager.currentSort.label,
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: theme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12.0),
                    sortWidget,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [titleWidget, sortWidget],
              );
            },
          ),
          const SizedBox(height: 20.0),

          // Table File List Workspace
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double minTableWidth = 550.0;
                final tableWidth = constraints.maxWidth > minTableWidth
                    ? constraints.maxWidth
                    : minTableWidth;

                return Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Titles Row
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 4.0,
                            ),
                            child: Row(
                              children: [
                                if (widget.isSelectionMode) ...[
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Checkbox(
                                      value: widget.areAllSelected,
                                      activeColor: theme.primaryColor,
                                      onChanged: (_) =>
                                          widget.onToggleSelectAll?.call(),
                                    ),
                                  ),
                                  const SizedBox(width: 16.0),
                                ],
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    'TITLE / AUTHOR',
                                    style: _headerTextStyle(theme),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'ALBUM',
                                    style: _headerTextStyle(theme),
                                  ),
                                ),
                                const SizedBox(width: 32),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.outerBackgroundColor,
                          ),
                          const SizedBox(height: 8.0),

                          // File List Workspace
                          Expanded(
                            child: ListView.builder(
                              controller: widget.scrollController,
                              itemCount: widget.fileListManager.length,
                              itemBuilder: (context, index) {
                                final track = widget.fileListManager
                                    .getCachedMetadataAtIndex(index);
                                final isActive = track.filePath ==
                                    widget.audioController.currentPath;

                                return _buildFileRow(
                                  context,
                                  theme,
                                  track,
                                  index,
                                  isActive,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _headerTextStyle(IAppTheme theme) {
    return TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      color: theme.textMuted,
      letterSpacing: 0.8,
    );
  }

  Widget _buildFileRow(
      BuildContext context,
      IAppTheme theme,
      TrackMetadataItem track,
      int index,
      bool isActive,
      ) {
    final bool isSelected = widget.selectedIndices.contains(index);

    return Material(
      color: isSelected
          ? theme.primaryColor.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8.0),
      child: InkWell(
        onTap: () {
          if (widget.isSelectionMode) {
            widget.onToggleSelect?.call(index);
          } else {
            widget.onPlayTrack(track.filePath);
          }
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              if (widget.isSelectionMode) ...[
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: theme.primaryColor,
                    onChanged: (_) => widget.onToggleSelect?.call(index),
                  ),
                ),
                const SizedBox(width: 16.0),
              ],
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    TrackArtworkWidget(theme: theme, track: track),
                    const SizedBox(width: 14.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            track.title,
                            style: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? theme.primaryColor
                                  : theme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w500,
                              color: theme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  track.album.isNotEmpty ? track.album : '—',
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: theme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 32,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18.0,
                    color: theme.textMuted,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) {
                    switch (value) {
                      case 'play_now':
                        widget.onPlayTrack(track.filePath);
                        break;
                      case 'play_next':
                        widget.onMoveToNext?.call(index);
                        break;
                      case 'delete':
                        widget.onDelete?.call(index);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'play_now',
                      child: Row(
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 18,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Text('Play Now'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'play_next',
                      child: Row(
                        children: [
                          Icon(
                            Icons.playlist_add_rounded,
                            size: 18,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Text('Play Next'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
