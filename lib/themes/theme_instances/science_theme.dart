import 'package:flutter/material.dart';
import '../app_theme_interface.dart';

class ScienceTheme implements IAppTheme {
  @override
  final Color primaryColor = const Color(0xFF00B2FF); // Cyan / Electric Blue Accent

  @override
  final Color cardBackgroundColor = const Color(0xFF070D18); // Deep Cyber/Sci-Fi Dark Blue

  @override
  final Color outerBackgroundColor = const Color(0xFF02050A); // Near-Black Void Blue

  @override
  final Color textPrimary = const Color(0xFFE0F7FF); // High-contrast Holographic White

  @override
  final Color textSecondary = const Color(0xFF5B7A9C); // Muted Tech Steel Blue

  @override
  final Color textMuted = const Color(0xFF22354D); // Deep HUD Grid Blue

  @override
  final double cardCornerRadius = 28.0;

  @override
  final double imageCornerRadius = 20.0;

  @override
  late final Icon themeIcon = Icon(Icons.memory_rounded, color: primaryColor);

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
          letterSpacing: 1.2,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}