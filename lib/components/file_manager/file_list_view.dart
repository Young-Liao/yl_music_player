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
      // ... (keep your existing Container decoration and padding)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... (keep your existing Header LayoutBuilder code)
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
                  thumbVisibility: true, // Keeps the scrollbar visible
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
                                SizedBox(
                                  width: 80,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'TIME',
                                      style: _headerTextStyle(theme),
                                    ),
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
                width: 80,
                child: Text(
                  formatDuration(track.duration.inSeconds.toDouble()),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w500,
                    color: theme.textSecondary,
                  ),
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
