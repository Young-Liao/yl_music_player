import 'package:flutter/material.dart';
import 'package:yl_music_player/pages/player_page.dart';
import 'package:yl_music_player/themes/light_theme.dart';
import 'package:yl_music_player/themes/theme_provider.dart';
import 'configs/window.dart';

void main() async {
  await WindowConfig.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final activeTheme = LightTheme();

    return CustomThemeProvider(
        theme: activeTheme,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'YL Music Player',
          theme: activeTheme.themeData,
          home: const PlayerPage(),
        ),
    );
  }
}
