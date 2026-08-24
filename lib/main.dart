import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:yl_music_player/components/player/playback_controls.dart';
import 'package:yl_music_player/controllers/audio/audio_player_controller.dart';
import 'package:yl_music_player/controllers/song_list/file_list_manager.dart';
import 'package:yl_music_player/navigation/app_router.dart';
import 'package:yl_music_player/pages/file_manager_page.dart';
import 'package:yl_music_player/pages/player_page.dart';
import 'package:yl_music_player/system/system_media_handler.dart';
import 'package:yl_music_player/themes/theme_provider.dart';
import 'package:yl_music_player/themes/themes.dart';
import 'package:yl_music_player/utils/link_service.dart';
import 'package:yl_music_player/utils/storage/database/interface.dart';
import 'package:yl_music_player/utils/storage/database/sqlite.dart';
import 'package:yl_music_player/utils/storage/settings.dart';
import 'configs/window.dart';
import 'controllers/lyrics/lyrics_handler.dart';
import 'controllers/song_list/playlist_manager.dart';
import 'controllers/themes/theme_controller.dart';

late SystemMediaHandler systemMediaHandler;
late IDatabaseStorage dbStorage;

final AudioPlayerController audioPlayerController = AudioPlayerController();
final playlistManager = PlaylistManager(db: dbStorage);
final lyricsHandler = LyricsHandler();
final fileListManager = FileListManager(db: dbStorage);

final playbackControlKey = GlobalKey<PlaybackControlsState>();

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowConfig.init();

  await SettingsStorage.instance.init();
  dbStorage = SQLiteStorage();
  await dbStorage.init();

  ThemeController.instance.init();

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
  LinkService.instance.init(initialArgs: args);

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
            home: ListenableBuilder(
              listenable: AppRouter.instance,
              builder: (context, _) {
                return IndexedStack(
                  index: AppRouter.instance.currentIndex,
                  children: [
                    PlayerPage(
                      playlistManager: playlistManager,
                      lyricsHandler: lyricsHandler,
                    ),
                    FileManagerPage(
                      audioController: audioPlayerController,
                      fileListManager: fileListManager,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
