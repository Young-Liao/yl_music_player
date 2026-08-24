import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:yl_music_player/main.dart';
import '../../controllers/audio/audio_player_controller.dart';
import '../../controllers/song_list/file_list_manager.dart';
import '../../themes/theme_provider.dart';
import '../../utils/file/file_picker.dart';
import 'file_list_view.dart';

final GlobalKey<MusicFilesWindowState> musicFilesWindowKey =
GlobalKey<MusicFilesWindowState>();

class MusicFilesWindow extends StatefulWidget {
  final AudioPlayerController audioController;
  final FileListManager fileListManager;
  final ValueChanged<String> onPlayTrack;
  final bool isSelectionMode;
  final bool isSubjectiveSelection;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onConfirmSubjectiveSelection;

  MusicFilesWindow({
    Key? key,
    required this.audioController,
    required this.fileListManager,
    required this.onPlayTrack,
    required this.isSelectionMode,
    required this.isSubjectiveSelection,
    required this.onToggleSelectionMode,
    required this.onConfirmSubjectiveSelection,
  }) : super(key: key ?? musicFilesWindowKey);

  @override
  State<MusicFilesWindow> createState() => MusicFilesWindowState();
}

class MusicFilesWindowState extends State<MusicFilesWindow> {
  late final ScrollController _scrollController;
  final Set<int> selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.fileListManager.loadListFromDb();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void clearSelection() {
    setState(() {
      selectedIndices.clear();
    });
  }

  Future<List<String>> _handleAdd() async {
    List<String> paths = await pickMultipleMusicFiles();
    if (paths.isEmpty) return paths;

    for (final path in paths) {
      if (widget.fileListManager.peekCache(path) == null) {
        final metadata = await widget.fileListManager.extractMetadata(path);
        widget.fileListManager.putToCache(path, metadata);
      }

      widget.fileListManager.addFileAt(path, 0);
    }

    widget.fileListManager.setSortOption(widget.fileListManager.currentSort);

    if (mounted) setState(() {});

    return paths;
  }

  void _toggleSelectIndex(int index) {
    setState(() {
      if (selectedIndices.contains(index)) {
        selectedIndices.remove(index);
      } else {
        selectedIndices.add(index);
      }
    });
  }

  void _handleBatchDelete() {
    if (selectedIndices.isEmpty) return;

    final sortedIndices = selectedIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final index in sortedIndices) {
      widget.fileListManager.deleteItem(index);
    }

    widget.onToggleSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Top Bar Actions
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 520;

              return Row(
                children: [
                  _ActionButton(
                    icon: widget.isSelectionMode
                        ? BootstrapIcons.x_circle
                        : BootstrapIcons.check2_square,
                    label: widget.isSelectionMode ? 'Cancel' : 'Select',
                    showLabel: !isCompact,
                    onPressed: widget.onToggleSelectionMode,
                    theme: theme,
                  ),
                  if (widget.isSelectionMode) ...[
                    const SizedBox(width: 8.0),
                    if (widget.isSubjectiveSelection)
                      ElevatedButton.icon(
                        onPressed: widget.onConfirmSubjectiveSelection,
                        icon: const Icon(BootstrapIcons.check_lg, size: 14.0),
                        label: Text(
                          isCompact
                              ? 'OK (${selectedIndices.length})'
                              : 'OK (${selectedIndices.length} Selected)',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: selectedIndices.isEmpty
                            ? null
                            : _handleBatchDelete,
                        icon: const Icon(BootstrapIcons.trash, size: 14.0),
                        label: Text(
                          isCompact
                              ? '${selectedIndices.length}'
                              : 'Delete Selected (${selectedIndices.length})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 14.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                  ],
                  const Spacer(),
                  if (!widget.isSelectionMode) ...[
                    _ActionButton(
                      icon: BootstrapIcons.grid,
                      label: 'Icon View',
                      showLabel: !isCompact,
                      onPressed: () {},
                      theme: theme,
                    ),
                    const SizedBox(width: 8.0),
                    _ActionButton(
                      icon: BootstrapIcons.display,
                      label: 'LAN Transfer',
                      showLabel: !isCompact,
                      onPressed: () {},
                      theme: theme,
                    ),
                    const SizedBox(width: 8.0),
                    ElevatedButton.icon(
                      onPressed: _handleAdd,
                      icon: const Icon(BootstrapIcons.upload, size: 14.0),
                      label: isCompact
                          ? const SizedBox.shrink()
                          : const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16.0),

          // Table File List Workspace
          Expanded(
            child: FileListView(
              fileListManager: widget.fileListManager,
              audioController: widget.audioController,
              onPlayTrack: widget.onPlayTrack,
              scrollController: _scrollController,
              isSelectionMode: widget.isSelectionMode,
              selectedIndices: selectedIndices,
              onToggleSelect: _toggleSelectIndex,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showLabel;
  final VoidCallback onPressed;
  final dynamic theme;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.showLabel = true,
    required this.onPressed,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!showLabel) {
      return Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          border: Border.all(color: theme.textMuted.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(icon, size: 16.0, color: theme.textPrimary),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14.0, color: theme.textPrimary),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.textMuted.withValues(alpha: 0.2)),
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }
}
