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

        // Primary Upload Action Button
        Widget buildUploadButton() {
          final button = ElevatedButton.icon(
            onPressed: null,
            icon: const Icon(BootstrapIcons.upload, size: 14.0),
            label: const Text('Upload'),
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
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          );

          return PopupMenuButton<String>(
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
            child: isCompact ? SizedBox(width: double.infinity, child: button) : button,
          );
        }

        // Primary Action in Selection Mode
        Widget buildSelectionPrimaryButton() {
          final isConfirm = isSubjectiveSelection || isLanTransferSelection;
          final button = ElevatedButton.icon(
            onPressed: selectedCount == 0
                ? null
                : (isConfirm ? onConfirmSelection : onBatchDelete),
            icon: Icon(
              isConfirm ? BootstrapIcons.check_lg : BootstrapIcons.trash,
              size: 14.0,
            ),
            label: Text(
              isConfirm
                  ? (isCompact ? 'OK ($selectedCount)' : 'OK ($selectedCount Selected)')
                  : (isCompact ? 'Delete ($selectedCount)' : 'Delete Selected ($selectedCount)'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isConfirm ? theme.primaryColor : Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 14.0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          );

          return isCompact ? SizedBox(width: double.infinity, child: button) : button;
        }

        return Row(
          children: [
            // Select / Cancel Action Button
            ActionButton(
              icon: isActiveSelectionMode
                  ? BootstrapIcons.x_circle
                  : BootstrapIcons.check2_square,
              label: isActiveSelectionMode ? 'Cancel' : 'Select',
              showLabel: true,
              onPressed: onToggleSelection,
              theme: theme,
            ),

            const SizedBox(width: 8.0),

            // LAN Transfer Button (icon-only in compact, full label in desktop)
            if (!isActiveSelectionMode && isTransferEnabled) ...[
              ActionButton(
                icon: BootstrapIcons.display,
                label: 'LAN Transfer',
                showLabel: !isCompact,
                onPressed: onLanTransferPressed,
                theme: theme,
              ),
              const SizedBox(width: 8.0),
            ],

            if (!isCompact) const Spacer(),

            // Primary action fills remaining width in compact view
            if (isActiveSelectionMode)
              isCompact
                  ? Expanded(child: buildSelectionPrimaryButton())
                  : buildSelectionPrimaryButton()
            else
              isCompact
                  ? Expanded(child: buildUploadButton())
                  : buildUploadButton(),
          ],
        );
      },
    );
  }
}
