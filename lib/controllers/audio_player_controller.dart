import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:metadata_god/metadata_god.dart';

class AudioPlayerController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  // Track Metadata
  String title = 'Unknown Title';
  String artist = 'Unknown Artist';
  Uint8List? artworkBytes; // Stores embedded cover art raw bytes

  // Playback State
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double volume = 0.7;

  AudioPlayerController() {
    _initStreams();
  }

  void _initStreams() {
    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      notifyListeners();
    });

    _player.positionStream.listen((pos) {
      position = pos;
      notifyListeners();
    });

    _player.durationStream.listen((dur) {
      duration = dur ?? Duration.zero;
      notifyListeners();
    });
  }

  /// Load track and automatically extract embedded ID3 metadata
  Future<void> loadTrack(String path, {bool isLocalFile = true}) async {
    try {
      if (isLocalFile) {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('File does not exist: $path');
          return;
        }

        // 1. Extract Metadata from Audio File
        final metadata = await MetadataGod.readMetadata(file: path);

        title = metadata.title ?? file.path.split('/').last.replaceAll('.mp3', '');
        artist = metadata.artist ?? 'Unknown Artist';
        artworkBytes = metadata.picture?.data; // Extract cover art bytes

        // 2. Load into Audio Player
        await _player.setFilePath(path);
      } else {
        await _player.setUrl(path);
      }
    } catch (e) {
      debugPrint('Error reading track metadata/audio: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> setPlaying(bool play) async {
    if (play) {
      _player.play();
    } else {
      await _player.pause();
    }
  }

  void seek(Duration pos) {
    _player.seek(pos);
  }

  void setVolume(double val) {
    volume = val;
    _player.setVolume(val);
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
