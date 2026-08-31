import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:yl_music_player/main.dart';
import '../../../themes/theme_provider.dart';
import 'action_button.dart';

class FileManagerActionBar extends StatelessWidget {
  final bool isActiveSelectionMode;
  final bool isLanTransferSelection;
  final bool isSubjectiveSelection;
  final int selectedCount;
  final VoidCallback onToggleSelection;
  final VoidCallback onConfirmSelection;
  final VoidCallback onBatchDelete;
  final VoidCallback onLanTransferPressed;

  // Replaced single upload callback with separate file and folder callbacks
  final VoidCallback onUploadFilesPressed;
  final VoidCallback onUploadFolderPressed;

  final VoidCallback? onToggleIconView;

  const FileManagerActionBar({
    super.key,
    required this.isActiveSelectionMode,
    required this.isLanTransferSelection,
    required this.isSubjectiveSelection,
    required this.selectedCount,
    required this.onToggleSelection,
    required this.onConfirmSelection,
    required this.onBatchDelete,
    required this.onLanTransferPressed,
    required this.onUploadFilesPressed,
    required this.onUploadFolderPressed,
    this.onToggleIconView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 520;

        return Row(
          children: [
            ActionButton(
              icon: isActiveSelectionMode
                  ? BootstrapIcons.x_circle
                  : BootstrapIcons.check2_square,
              label: isActiveSelectionMode ? 'Cancel' : 'Select',
              showLabel: !isCompact,
              onPressed: onToggleSelection,
              theme: theme,
            ),
            if (isActiveSelectionMode) ...[
              const SizedBox(width: 8.0),
              if (isSubjectiveSelection || isLanTransferSelection)
                ElevatedButton.icon(
                  onPressed: selectedCount == 0 ? null : onConfirmSelection,
                  icon: const Icon(BootstrapIcons.check_lg, size: 14.0),
                  label: Text(
                    isCompact
                        ? 'OK ($selectedCount)'
                        : 'OK ($selectedCount Selected)',
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
                  onPressed: selectedCount == 0 ? null : onBatchDelete,
                  icon: const Icon(BootstrapIcons.trash, size: 14.0),
                  label: Text(
                    isCompact ? '$selectedCount' : 'Delete Selected ($selectedCount) (Tracks Only)',
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
            if (!isActiveSelectionMode) ...[
              const SizedBox(width: 8.0),
              if (isTransferEnabled)
                ActionButton(
                  icon: BootstrapIcons.display,
                  label: 'LAN Transfer',
                  showLabel: !isCompact,
                  onPressed: onLanTransferPressed,
                  theme: theme,
                ),
              const SizedBox(width: 8.0),

              // Upload Button upgraded with PopupMenuButton and Tooltips
              PopupMenuButton<String>(
                offset: const Offset(0, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                onSelected: (value) {
                  if (value == 'files') {
                    onUploadFilesPressed();
                  } else if (value == 'folder') {
                    onUploadFolderPressed();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'files',
                    child: Tooltip(
                      message: 'Directly add files to root',
                      child: Row(
                        children: [
                          Icon(BootstrapIcons.file_earmark_music, size: 16),
                          SizedBox(width: 10),
                          Text('Upload File(s)'),
                        ],
                      ),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'folder',
                    child: Tooltip(
                      message: 'Upload songs and group them by folders',
                      child: Row(
                        children: [
                          Icon(BootstrapIcons.folder_plus, size: 16),
                          SizedBox(width: 10),
                          Text('Upload a Folder'),
                        ],
                      ),
                    ),
                  ),
                ],
                child: ElevatedButton.icon(
                  onPressed: null, // Handled by PopupMenuButton wrapper, keeps button styling active
                  icon: const Icon(BootstrapIcons.upload, size: 14.0),
                  label: isCompact
                      ? const SizedBox.shrink()
                      : const Text('Upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    disabledBackgroundColor: theme.primaryColor,
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
              ),
            ],
          ],
        );
      },
    );
  }
}
