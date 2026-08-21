import 'package:flutter/material.dart';

/// Interface defining all required design tokens
abstract interface class IAppTheme {
  /// Brand Colors
  abstract final Color primaryColor;
  abstract final Color cardBackgroundColor;
  abstract final Color outerBackgroundColor;

  /// Text Colors
  abstract final Color textPrimary;
  abstract final Color textSecondary;
  abstract final Color textMuted;

  /// Dimensions & Radius
  abstract final double cardCornerRadius;
  abstract final double imageCornerRadius;

  /// Flutter ThemeData builder
  ThemeData get themeData;
}