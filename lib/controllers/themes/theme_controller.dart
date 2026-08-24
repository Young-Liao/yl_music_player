import 'package:flutter/material.dart';
import 'package:yl_music_player/utils/storage/settings.dart';

import '../../themes/themes.dart';

class ThemeController extends ValueNotifier<IAppTheme> {
  ThemeController._() : super(availableThemes[0]);

  static final ThemeController instance = ThemeController._();

  static final List<IAppTheme> availableThemes = [
    LightTheme(),
    DarkTheme(),
    ScienceTheme(),
  ];

  /// 2. Must be called AFTER `await SettingsStorage.instance.init()`
  void init() {
    final savedIndex = SettingsStorage.instance.themeIndex;
    if (savedIndex >= 0 && savedIndex < availableThemes.length) {
      value = availableThemes[savedIndex];
    } else {
      value = availableThemes[0];
    }
  }

  void toggleTheme() {
    SettingsStorage.instance.setThemeIndex((SettingsStorage.instance.themeIndex + 1) % availableThemes.length);
    value = availableThemes[SettingsStorage.instance.themeIndex];
  }
}
