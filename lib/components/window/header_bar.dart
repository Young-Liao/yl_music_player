import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yl_music_player/components/window/page_segmented_control.dart';
import '../../controllers/themes/theme_controller.dart';
import '../../themes/theme_provider.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final isWindowsOrLinux =
        !kIsWeb && (Platform.isWindows || Platform.isLinux);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Top padding strip transformed into a drag handle
        DragToMoveArea(
          child: Container(
            height: 20.0,
            color: Colors.transparent,
          ),
        ),

        // 2. Main title row
        SizedBox(
          height: 40.0,
          child: Row(
            children: [
              // Left Title Section
              Expanded(
                flex: 2,
                child: DragToMoveArea(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.centerLeft,
                    color: Colors.transparent,
                    child: Text(
                      'YL Music Player',
                      style: TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              // Center Segmented Navigation Switcher
              const Expanded(
                flex: 3,
                child: Center(
                  child: PageSegmentedControl(),
                ),
              ),

              // Right Action Buttons
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: ThemeController.instance.toggleTheme,
                      icon: theme.themeIcon,
                      splashRadius: 20,
                    ),
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
