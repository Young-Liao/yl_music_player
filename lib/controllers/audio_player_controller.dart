import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as p;

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
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  double volume = 0.7;
  LoopType loopType = LoopType.loop;  // TODO: Save to settings files.
  bool _isLoading = false;

  AudioPlayerController({required this.playbackCompleted}) {
    _initStreams();
    loadEmpty();
  }

  void _initStreams() {
    _player.playerStateStream.listen((state) {
      isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        playbackCompleted();
      }
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
      Uri audioUri;

      if (isLocalFile) {
        final file = File(path);
        if (!await file.exists()) {
          debugPrint('File does not exist: $path');
          return;
        }

        try {
          final metadata = await MetadataGod.readMetadata(file: path);
          title = metadata.title ?? p.basenameWithoutExtension(path);
          artist = metadata.artist ?? 'Unknown Artist';
          artworkBytes = metadata.picture?.data;
        } catch (e) {
          debugPrint('Error reading metadata: $e');
          title = p.basenameWithoutExtension(path);
          artist = 'Unknown Artist';
          artworkBytes = null;
        }

        if (Platform.isWindows) {
          await Future.delayed(const Duration(milliseconds: 10));
          audioUri = Uri.file(file.absolute.path, windows: true);
        } else {
          audioUri = file.uri;
        }

        await _player.stop();

        await _player.setAudioSource(
          AudioSource.uri(audioUri),
          preload: false,
        );
      } else {
        audioUri = Uri.parse(path);
        await _player.setAudioSource(AudioSource.uri(audioUri));
      }

      final loadedDuration = await _player.load();
      if (loadedDuration != null) {
        duration = loadedDuration;
      }

      currentPath = path;
    } catch (e) {
      debugPrint('Error loading audio source: $e');
    } finally {
      _isLoading = false;
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
