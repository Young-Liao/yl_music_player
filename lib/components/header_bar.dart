import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../themes/theme_provider.dart';

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final isWindowsOrLinux = !kIsWeb && (Platform.isWindows || Platform.isLinux);

    return DragToMoveArea(
      child: Container(
        height: 48.0,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          children: [
            Text(
              'YL Music Player',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {
                // TODO: SWITCHING THEMES
              },
              icon: Icon(
                Icons.wb_sunny_rounded,
                color: theme.primaryColor,
              ),
              splashRadius: 20,
            ),
            if (isWindowsOrLinux) ...[
              const SizedBox(width: 8.0),
              _WindowButtons(theme: theme),
            ],
          ],
        ),
      ),
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
          icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
          splashRadius: 18,
          onPressed: () async => await windowManager.close(),
        ),
      ],
    );
  }
}
