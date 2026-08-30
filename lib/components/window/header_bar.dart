import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../controllers/themes/theme_controller.dart';
import '../../main.dart'; // Reference to global lanTransferController and getDeviceName()
import '../../themes/theme_provider.dart';
import '../window/page_segmented_control.dart';

class HeaderBar extends StatefulWidget {
  final ValueChanged<bool>? onTransferServiceChanged;

  const HeaderBar({
    super.key,
    this.onTransferServiceChanged,
  });

  @override
  State<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends State<HeaderBar> {
  Future<void> _toggleTransferService(bool enabled) async {
    setState(() {
      isTransferEnabled = enabled;
    });

    if (enabled) {
      await lanTransferController.initService();
    } else {
      await lanTransferController.stopService();
    }

    widget.onTransferServiceChanged?.call(enabled);
  }

  @override
  void dispose() {
    // Ensure the service is stopped when the widget/window closes
    if (isTransferEnabled) {
      lanTransferController.stopService();
      widget.onTransferServiceChanged?.call(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final isWindowsOrLinux =
        !kIsWeb && (Platform.isWindows || Platform.isLinux);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 600;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top padding strip drag handle
            DragToMoveArea(
              child: Container(
                height: 20.0,
                color: Colors.transparent,
              ),
            ),

            // Main title row
            SizedBox(
              height: 40.0,
              child: Row(
                children: [
                  // Left Title Section
                  Expanded(
                    flex: isNarrow ? 3 : 2,
                    child: DragToMoveArea(
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.centerLeft,
                        color: Colors.transparent,
                        child: Text(
                          'YL Music Player',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: isNarrow ? 15.0 : 18.0,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Center Segmented Navigation Switcher
                  Expanded(
                    flex: isNarrow ? 2 : 3,
                    child: Center(
                      child: PageSegmentedControl(showLabels: !isNarrow),
                    ),
                  ),

                  // Right Action Buttons
                  Expanded(
                    flex: isNarrow ? 2 : 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // --- LAN File Transfer Switcher ---
                        Tooltip(
                          message: isTransferEnabled
                              ? 'LAN Transfer Enabled'
                              : 'Enable LAN Transfer',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sync_alt_rounded,
                                size: 18,
                                color: isTransferEnabled
                                    ? theme.primaryColor
                                    : theme.textSecondary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Transform.scale(
                                scale: 0.75,
                                child: Switch(
                                  value: isTransferEnabled,
                                  activeTrackColor: theme.primaryColor,
                                  onChanged: _toggleTransferService,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 4.0),

                        // Theme Toggle Button
                        IconButton(
                          onPressed: ThemeController.instance.toggleTheme,
                          icon: theme.themeIcon,
                          splashRadius: 20,
                        ),

                        // Desktop Window Control Buttons
                        if (isWindowsOrLinux) ...[
                          const SizedBox(width: 4.0),
                          _WindowButtons(theme: theme),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WindowButtons extends StatelessWidget {
  final dynamic theme;

  const _WindowButtons({required this.theme});

  @override
  Widget build(BuildContext context) {
    final iconColor = theme.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.remove_rounded, size: 18, color: iconColor),
          splashRadius: 18,
          onPressed: () async => await windowManager.minimize(),
        ),
        IconButton(
          icon: Icon(Icons.crop_square_rounded, size: 16, color: iconColor),
          splashRadius: 18,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        IconButton(
          icon: const Icon(
            Icons.close_rounded,
            size: 18,
            color: Colors.redAccent,
          ),
          splashRadius: 18,
          onPressed: () async => await windowManager.close(),
        ),
      ],
    );
  }
}
