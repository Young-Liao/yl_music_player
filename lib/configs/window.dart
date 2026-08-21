import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowConfig {
  // Configure target mobile window dimensions
  static const double width = 390.0;
  static const double height = 844.0;

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(width, height),
      minimumSize: Size(width, height),
      maximumSize: Size(width, height),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "Mobile Simulator",
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}