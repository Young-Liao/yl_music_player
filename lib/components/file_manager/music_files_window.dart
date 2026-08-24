import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import '../../controllers/audio/audio_player_controller.dart';
import '../../controllers/song_list/file_list_manager.dart';
import '../../themes/theme_provider.dart';
import '../../utils/file/file_picker.dart';
import 'file_list_view.dart';

class MusicFilesWindow extends StatefulWidget {
  final AudioPlayerController audioController;
  final FileListManager fileListManager;
  final ValueChanged<String> onPlayTrack;

  const MusicFilesWindow({
    super.key,
    required this.audioController,
    required this.fileListManager,
    required this.onPlayTrack,
  });

  @override
  State<MusicFilesWindow> createState() => _MusicFilesWindowState();
}

class _MusicFilesWindowState extends State<MusicFilesWindow> {
  late final ScrollController _scrollController;

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

  Future<List<String>> _handleAdd() async {
    List<String> paths = await pickMultipleMusicFiles();
    if (paths.isEmpty) return paths;

    for (final path in paths) {
      // 1. Ensure metadata is extracted and cached *before* adding to the path list
      if (widget.fileListManager.peekCache(path) == null) {
        final metadata = await widget.fileListManager.extractMetadata(path);
        widget.fileListManager.putToCache(path, metadata);
      }

      // 2. Add file to the list manager
      widget.fileListManager.addFileAt(path, 0);
    }

    // 3. Re-sort if a sort option is active so it lands in the correct position
    widget.fileListManager.setSortOption(widget.fileListManager.currentSort);

    if (mounted) setState(() {});

    return paths;
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Top Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 520;

              return Row(
                children: [
                  const Spacer(),
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
                    label: isCompact ? const SizedBox.shrink() : const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ),
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
      return IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 16.0, color: theme.textPrimary),
        style: IconButton.styleFrom(
          side: BorderSide(color: theme.textMuted.withValues(alpha: 0.2)),
          padding: const EdgeInsets.all(12.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14.0, color: theme.textPrimary),
      label: Text(
        label,
        style: TextStyle(fontSize: 13.0, fontWeight: FontWeight.w600, color: theme.textPrimary),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: theme.textMuted.withValues(alpha: 0.2)),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 14.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}
