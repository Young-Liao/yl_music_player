import 'package:flutter/material.dart';
import 'app_theme_interface.dart';

class CustomThemeProvider extends InheritedWidget {
  final IAppTheme theme;

  const CustomThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  static IAppTheme of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<CustomThemeProvider>();
    assert(provider != null, 'No CustomThemeProvider found in context');
    return provider!.theme;
  }

  @override
  bool updateShouldNotify(CustomThemeProvider oldWidget) => theme != oldWidget.theme;
}
