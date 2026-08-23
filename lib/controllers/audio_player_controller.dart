import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:yl_music_player/controllers/system_media_sync_controller.dart';

import '../utils/lyrics_handler.dart';

enum LoopType { loop, repeat }

class AudioPlayerController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final Function playbackCompleted;

  // Track Metadata
  late String currentPath;
  late String title;
  late String artist;
  late Uint8List? artworkBytes; // Stores embedded cover art raw bytes

  // Playback State
  bool isPlaying = false;
  bool loaded = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double volume = 0.7;
  LoopType loopType = LoopType.loop;
  bool _isLoading = false;
  bool _forceStopped = false;
  File? _windowsTempFile;

  LyricsHandler? lyricsHandler;
  String? _lastSyncedLyricLine;

  AudioPlayerController({required this.playbackCompleted}) {
    _initStreams();
    loadEmpty();
  }

  void _initStreams() {
    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed ||
          (state.processingState == ProcessingState.idle && _forceStopped)) {
        loaded = false;
        playbackCompleted();
        _forceStopped = false;
      }
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      position = pos;
      notifyListeners();

      // 1. Ensure lyrics handler is available
      final handler = lyricsHandler;
      if (handler == null || handler.isEmpty) return;

      // 2. Resolve active line index and text
      final activeIndices = handler.getCurrentIndices(pos);
      final String? currentLyric = activeIndices.isNotEmpty
          ? handler.lines[activeIndices.first].text
          : null;

      // 3. Guard: Sync ONLY when the lyric line actually changes
      if (_lastSyncedLyricLine != currentLyric) {
        _lastSyncedLyricLine = currentLyric;

        SystemMediaSyncController.sync(
          songId: currentPath,
          title: title,
          artist: artist,
          artworkBytes: artworkBytes,
          position: pos,
          duration: duration,
          isPlaying: isPlaying,
          lyricsHandler: handler,
        );
      }
    });

    _player.durationStream.listen((dur) {
      duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  void resetLyrics() => _lastSyncedLyricLine = null;

  void loadEmpty() {
    currentPath = '';
    title = 'Unknown Title';
    artist = 'Unknown Artist';
    artworkBytes = null;
    setPlaying(false);
  }

  /// Load track and automatically extract embedded ID3 metadata
  Future<void> loadTrack(String path, {bool isLocalFile = true}) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      if (isLocalFile) {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('File does not exist: $path');
          return;
        }

        // 1. 尝试使用 MetadataGod 读取元数据（处理中文路径文件名 fallback）
        try {
          final metadata = await MetadataGod.readMetadata(file: file.path);
          title = metadata.title ?? p.basenameWithoutExtension(file.path);
          artist = metadata.artist ?? 'Unknown Artist';
          artworkBytes = metadata.picture?.data;
          if (metadata.durationMs != null) {
            duration = Duration(milliseconds: metadata.durationMs!.toInt());
          }
        } catch (e) {
          debugPrint('Error reading metadata: $e');
          title = p.basenameWithoutExtension(file.path);
          artist = 'Unknown Artist';
          artworkBytes = null;
        }
        await _player.stop();

        if (Platform.isWindows) {
          // 先清理上一个临时文件
          if (_windowsTempFile != null && await _windowsTempFile!.exists()) {
            try {
              await _windowsTempFile!.delete();
            } catch (_) {}
          }

          // 获取系统的临时目录（该目录通常全英文）
          final tempDir = await getTemporaryDirectory();
          // 使用一个固定英文名作为临时文件（如 temp_play.mp3），避开原名中的中文
          final tempPath = p.join(
            tempDir.path,
            'temp_play${p.extension(path)}',
          );

          // 将包含中文的文件内容快速复制过去
          _windowsTempFile = await file.copy(tempPath);

          // 让播放器去播放这个绝对不包含中文的临时文件
          await _player.setAudioSource(
            AudioSource.file(_windowsTempFile!.path),
            preload: false,
          );
        } else {
          // macOS 依然走原有的正常逻辑
          await _player.setAudioSource(
            AudioSource.uri(file.uri),
            preload: false,
          );
        }
      } else {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(path)));
      }

      final loadedDuration = await _player.load();
      if (loadedDuration != null) {
        duration = loadedDuration;
      }

      currentPath = path;
      loaded = true;
    } catch (e) {
      debugPrint('Error loading audio source: $e');
    } finally {
      _isLoading = false;
      resetLyrics();
      notifyListeners();
    }
  }

  Future<void> setPlaying(bool play) async {
    if (play) {
      await _player.play();
    } else {
      await _player.pause();
    }
  }

  void seek(Duration pos) => _player.seek(pos);

  void setVolume(double val) {
    volume = val;
    _player.setVolume(val);
    notifyListeners();
  }

  void stop() {
    _player.stop();
    _forceStopped = true;
    loaded = false;
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
