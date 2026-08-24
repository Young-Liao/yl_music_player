import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import '../../themes/theme_provider.dart';

class MusicFilesWindow extends StatelessWidget {
  const MusicFilesWindow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Top Control Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 400;

              return Row(
                children: [
                  const Spacer(),

                  // View & Action Toolbar Controls
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

                  // Upload Action Button
                  if (isCompact)
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(BootstrapIcons.upload, size: 16.0),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      tooltip: 'Upload',
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(BootstrapIcons.upload, size: 14.0),
                      label: const Text(
                        'Upload',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
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
              );
            },
          ),

          // File List Workspace
          Expanded(
            child: Center(
              child: Text(
                'No music files found.',
                style: TextStyle(fontSize: 14.0, color: theme.textMuted),
              ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        tooltip: label,
      );
    }

    return OutlinedButton.icon(
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
        padding: const EdgeInsets.symmetric(
          horizontal: 14.0,
          vertical: 14.0,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}
