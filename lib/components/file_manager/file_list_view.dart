import 'package:flutter/material.dart';
import 'package:yl_music_player/utils/algorithms.dart';
import '../../themes/app_theme_interface.dart';
import '../../themes/theme_provider.dart';
import '../../utils/data_structures/track_metadata_item.dart';
import '../song_list/song_list_view.dart';
import '../../controllers/song_list/file_list_manager.dart';

class FileListView extends SongListView {
  final FileListManager fileListManager;

  const FileListView({
    super.key,
    required this.fileListManager,
    required super.audioController,
    required super.onPlayTrack,
    required super.scrollController,
    super.onMoveToNext,
    super.onDelete,
  }) : super(songListManager: fileListManager);

  @override
  State<SongListView> createState() => _FileListViewState();
}

class _FileListViewState extends SongListViewState {
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final fileManager = (widget.songListManager as FileListManager);

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
          // Responsive Header Bar using LayoutBuilder to prevent overflow
          LayoutBuilder(
            builder: (context, constraints) {
              // If width is tight (< 380px), stack title and sort vertically
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
                      shadowColor: const WidgetStatePropertyAll(Colors.black12),
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
                    menuChildren: FileListSortOption.values.map((
                      FileListSortOption option,
                    ) {
                      final isSelected = option == fileManager.currentSort;
                      return MenuItemButton(
                        style: ButtonStyle(
                          overlayColor: WidgetStateProperty.all(
                            Colors.transparent,
                          ),
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.hovered) || isSelected) {
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
                            fileManager.setSortOption(option);
                          });
                        },
                        child: Container(
                          width: 100,
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
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
                    builder:
                        (
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
                                    fileManager.currentSort.label,
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

          // Scrollable Table Wrapper with Scrollbar
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
                          // Column Titles Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
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

                          // File List Items Workspace
                          Expanded(
                            child: ListView.builder(
                              controller: widget.scrollController,
                              itemCount: fileManager.length,
                              itemBuilder: (context, index) {
                                final track = fileManager
                                    .getCachedMetadataAtIndex(index);
                                final isActive =
                                    track.filePath ==
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8.0),
      child: InkWell(
        onTap: () => widget.onPlayTrack(track.filePath),
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    buildTrackArtwork(theme, track),
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
                child: IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 18.0,
                    color: theme.textMuted,
                  ),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
