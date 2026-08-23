import 'package:flutter/material.dart';

import '../app_theme_interface.dart';

class DarkTheme implements IAppTheme {
  @override
  final Color primaryColor = const Color(0xFF818CF8); // Soft glowing purple accent

  @override
  final Color cardBackgroundColor = const Color(0xFF12131A); // Dark inner card container

  @override
  final Color outerBackgroundColor = const Color(0xFF0A0B0E); // Deep background

  @override
  final Color textPrimary = const Color(0xFFF3F4F6); // Bright contrast title text

  @override
  final Color textSecondary = const Color(0xFF9CA3AF); // Subdued artist/subtitle text

  @override
  final Color textMuted = const Color(0xFF4B5563); // Muted timestamp/placeholder text

  @override
  final double cardCornerRadius = 28.0;

  @override
  final double imageCornerRadius = 20.0;

  @override
  late final Icon themeIcon = Icon(Icons.nightlight_round, color: primaryColor);

  @override
  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: outerBackgroundColor,
      primaryColor: primaryColor,

      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      ),
    );
  }
}