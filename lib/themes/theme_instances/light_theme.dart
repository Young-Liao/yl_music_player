import 'package:flutter/material.dart';
import '../app_theme_interface.dart';

class LightTheme implements IAppTheme {
  @override
  final Color primaryColor = const Color(0xFF5B50E6);

  @override
  final Color cardBackgroundColor = Colors.white;

  @override
  final Color outerBackgroundColor = const Color(0xFFF2F4F7);

  @override
  final Color textPrimary = const Color(0xFF1D2939);

  @override
  final Color textSecondary = const Color(0xFF667085);

  @override
  final Color textMuted = const Color(0xFF98A2B3);

  @override
  final double cardCornerRadius = 28.0;

  @override
  final double imageCornerRadius = 20.0;

  @override
  late final Icon themeIcon = Icon(Icons.wb_sunny_rounded, color: primaryColor);

  @override
  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
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
