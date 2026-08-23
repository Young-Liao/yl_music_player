import 'package:flutter/material.dart';

import '../themes/themes.dart';

class ThemeController extends ValueNotifier<IAppTheme> {
  ThemeController._() : super(availableThemes[0]);

  static final ThemeController instance = ThemeController._();

  static final List<IAppTheme> availableThemes = [
    LightTheme(),
    DarkTheme(),
    ScienceTheme(),
  ];

  int _currentIndex = 0;

  void toggleTheme() {
    _currentIndex = (_currentIndex + 1) % availableThemes.length;
    value = availableThemes[_currentIndex];
  }
}
