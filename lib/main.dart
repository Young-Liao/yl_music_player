import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:yl_music_player/pages/player_page.dart';
import 'package:yl_music_player/system/system_media_handler.dart';
import 'package:yl_music_player/themes/light_theme.dart';
import 'package:yl_music_player/themes/theme_provider.dart';
import 'configs/window.dart';

late SystemMediaHandler systemMediaHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowConfig.init();

  systemMediaHandler = await AudioService.init(
    builder: () => SystemMediaHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.yl.music.channel.audio',
      androidNotificationChannelName: 'YL Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  await MetadataGod.initialize();
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
