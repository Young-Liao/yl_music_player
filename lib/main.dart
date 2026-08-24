import 'package:audio_service/audio_service.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:yl_music_player/pages/player_page.dart';
import 'package:yl_music_player/system/system_media_handler.dart';
import 'package:yl_music_player/themes/theme_provider.dart';
import 'package:yl_music_player/themes/themes.dart';
import 'package:yl_music_player/utils/link_service.dart';
import 'package:yl_music_player/utils/storage/database/interface.dart';
import 'package:yl_music_player/utils/storage/database/sqlite.dart';
import 'package:yl_music_player/utils/storage/settings.dart';
import 'configs/window.dart';
import 'controllers/lyrics_handler.dart';
import 'controllers/playlist_manager.dart';
import 'controllers/theme_controller.dart';

late SystemMediaHandler systemMediaHandler;
late IDatabaseStorage dbStorage;

void main(List<String> args) async {
  /// Window
  WidgetsFlutterBinding.ensureInitialized();
  await WindowConfig.init();

  /// Storage
  await SettingsStorage.instance.init();
  dbStorage = SQLiteStorage();
  await dbStorage.init();

  /// Theme
  ThemeController.instance.init();

  /// System
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

class _MyAppState extends State<MyApp> {
  bool _isDragging = false;

  final PlaylistManager _playlistManager = PlaylistManager(db: dbStorage);
  final LyricsHandler _lyricsHandler = LyricsHandler();

  static const _supportedAudioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
  };

  @override
  void initState() {
    super.initState();
  }

  /// Check if file extension matches supported audio formats
  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _supportedAudioExtensions.any(lower.endsWith);
  }

  /// Process audio files from either Drag & Drop or "Open With"
  void _handleIncomingFiles(List<String> rawPaths) {
    for (final path in rawPaths) {
      if (_isAudioFile(path)) {
        LinkService.instance.addLink(path);
      }
    }
  }

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
            home: DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (details) {
                setState(() => _isDragging = false);
                final paths = details.files
                    .map((XFile file) => file.path)
                    .toList();
                _handleIncomingFiles(paths);
              },
              child: Stack(
                children: [
                  PlayerPage(
                    playlistManager: _playlistManager,
                    lyricsHandler: _lyricsHandler,
                  ),
                  if (_isDragging)
                    Positioned.fill(
                      child: Container(
                        color: activeTheme.themeData.primaryColor.withOpacity(
                          0.2,
                        ),
                        child: Center(
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 24,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.library_music_rounded, size: 48),
                                  SizedBox(height: 12),
                                  Text(
                                    'Drop audio files to play',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
