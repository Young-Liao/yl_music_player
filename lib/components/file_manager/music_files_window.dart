import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import '../../controllers/audio/audio_player_controller.dart';
import '../../controllers/song_list/file_list_manager.dart';
import '../../themes/theme_provider.dart';
import 'file_list_view.dart';

class MusicFilesWindow extends StatelessWidget {
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
                    onPressed: () {},
                    icon: const Icon(BootstrapIcons.upload, size: 14.0),
                    label: isCompact ? const SizedBox.shrink() : const Text('Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
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
              fileListManager: fileListManager,
              audioController: audioController,
              onPlayTrack: onPlayTrack,
              scrollController: ScrollController(),
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
