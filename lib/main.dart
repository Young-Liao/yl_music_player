import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yl_music_player/components/player/playback_controls.dart';
import 'package:yl_music_player/controllers/audio/audio_player_controller.dart';
import 'package:yl_music_player/controllers/network/lan_transfer_controller.dart';
import 'package:yl_music_player/controllers/song_list/file_list_manager.dart';
import 'package:yl_music_player/navigation/app_router.dart';
import 'package:yl_music_player/pages/file_manager_page.dart';
import 'package:yl_music_player/pages/lan_receive_dialog.dart';
import 'package:yl_music_player/pages/player_page.dart';
import 'package:yl_music_player/pages/settings_page.dart';
import 'package:yl_music_player/system/system_media_handler.dart';
import 'package:yl_music_player/themes/theme_provider.dart';
import 'package:yl_music_player/themes/themes.dart';
import 'package:yl_music_player/utils/link_service.dart';
import 'package:yl_music_player/utils/storage/database/interface.dart';
import 'package:yl_music_player/utils/storage/database/sqlite.dart';
import 'package:yl_music_player/utils/storage/settings.dart';
import 'components/window/app_bottom_navigation_bar.dart';
import 'components/window/header_bar.dart';
import 'configs/window.dart';
import 'controllers/lyrics/lyrics_handler.dart';
import 'controllers/song_list/group_manager.dart';
import 'controllers/song_list/playlist_manager.dart';
import 'controllers/themes/theme_controller.dart';

late SystemMediaHandler systemMediaHandler;
late IDatabaseStorage dbStorage;

final AudioPlayerController audioPlayerController = AudioPlayerController();
late final PlaylistManager playlistManager;
final lyricsHandler = LyricsHandler();
late final FileListManager fileListManager;
final transferController = LanTransferController();
final lanTransferController = LanTransferController();
late final GroupManager groupManager;

final playbackControlKey = GlobalKey<PlaybackControlsState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool isTransferEnabled = false;

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowConfig.init();

  await SettingsStorage.instance.init();
  dbStorage = SQLiteStorage();
  await dbStorage.init();

  playlistManager = PlaylistManager(db: dbStorage);
  fileListManager = FileListManager(db: dbStorage);
  groupManager = GroupManager(db: dbStorage);

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _servicePaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // _initService();
    _initTransferServer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _disposeResources();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      lanTransferController.stopService();
      _servicePaused = true;
    } else if (_servicePaused) {
      _servicePaused = false;

      lanTransferController.initService();
    }
  }

  /// Clean up and release system resources when the application terminates
  void _disposeResources() {
    transferController.stopService();
    transferController.dispose();

    lanTransferController.stopService();
    lanTransferController.dispose();

    audioPlayerController.dispose();

    // Close database storage handles if implemented
    dbStorage.close();
  }

  Future<void> _initTransferServer() async {
    // Handshake Callback: Prompt user when incoming transfer batch is requested
    lanTransferController.onRequestReceived = (batchRequest) async {
      final Completer<bool> completer = Completer<bool>();

      LanReceiveDialog.show(
        navigatorKey.currentContext!,
        batchRequest: batchRequest,
        onAccept: () => completer.complete(true),
        onDecline: () => completer.complete(false),
      );

      return completer.future;
    };

    // Callback when binary stream saves a track file to disk
    lanTransferController.onTrackReceived = (tempPath) async {
      final docsDir = await getApplicationDocumentsDirectory();
      final targetFileName = tempPath.split(Platform.pathSeparator).last;
      final targetPath = '${docsDir.path}/$targetFileName';

      final savedFile = await File(tempPath).copy(targetPath);
      await File(tempPath).delete();

      if (mounted) {
        await fileListManager.addFileAt(savedFile.path, 0);
        setState(() {});
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IAppTheme>(
      valueListenable: ThemeController.instance,
      builder: (context, activeTheme, _) {
        return CustomThemeProvider(
          theme: activeTheme,
          child: MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'YL Music Player',
            theme: activeTheme.themeData,
            home: LayoutBuilder(
              builder: (context, constraints) {
                final bool isNarrow = constraints.maxWidth < 600;
                return Scaffold(
                  backgroundColor: activeTheme.outerBackgroundColor,
                  body: ListenableBuilder(
                    listenable: AppRouter.instance,
                    builder: (context, _) {
                      final theme = CustomThemeProvider.of(context);

                      return SafeArea(
                        child: Stack(
                          children: [
                            // 1. Foreground Layer: Full Main Card (Encloses HeaderBar & IndexedStack)
                            Padding(
                              padding: EdgeInsets.all(isNarrow ? 0.0 : 24.0),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                padding: const EdgeInsets.only(
                                  left: 24.0,
                                  right: 24.0,
                                  top: 12.0,
                                  bottom: 24.0,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.cardBackgroundColor,
                                  borderRadius: BorderRadius.circular(
                                    theme.cardCornerRadius,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // HeaderBar placed inside top of card
                                    const HeaderBar(),
                                    const SizedBox(height: 12.0),

                                    // Page Content Stack
                                    Expanded(
                                      child: IndexedStack(
                                        index: AppRoute.values.indexOf(
                                          AppRouter.instance.currentRoute,
                                        ),
                                        children: [
                                          PlayerPage(),
                                          FileManagerPage(),
                                          SettingsPage(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  bottomNavigationBar: AppBottomNavigationBar(),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
