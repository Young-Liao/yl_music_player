import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:yl_music_player/pages/player_page.dart';
import 'package:yl_music_player/system/system_media_handler.dart';
import 'package:yl_music_player/themes/theme_provider.dart';
import 'package:yl_music_player/themes/themes.dart';
import 'configs/window.dart';
import 'controllers/theme_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IAppTheme>(
      valueListenable: ThemeController.instance,
      builder: (context, activeTheme, _) {
        return CustomThemeProvider(
          theme: activeTheme,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'YL Music Player',
            theme: activeTheme.themeData,
            home: const PlayerPage(),
          ),
        );
      },
    );
  }
}
