import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LinkService {
  static final LinkService instance = LinkService._();
  LinkService._();

  // Matched exact channel name string with Swift AppDelegate / iOS / macOS
  static const _eventChannel = EventChannel('com.youngl.ylmusic/file_stream');
  final StreamController<String> _linkStreamController =
  StreamController<String>.broadcast();
  StreamSubscription? _fileSubscription;

  Stream<String> get linkStream => _linkStreamController.stream;

  static const _supportedAudioExtensions = {
    '.mp3',
    '.flac',
    '.wav',
    '.m4a',
    '.aac',
    '.ogg',
  };

  bool _isAudioFile(String path) {
    final lower = path.toLowerCase();
    return _supportedAudioExtensions.any(lower.endsWith);
  }

  void init({List<String>? initialArgs}) {
    // 1. Apple Ecosystem Stream (macOS & iOS Cold Start / Runtime)
    if (Platform.isMacOS || Platform.isIOS) {
      _fileSubscription = _eventChannel.receiveBroadcastStream().listen(
            (dynamic event) {
          if (event is List) {
            for (final item in event) {
              if (item is String) _processPath(item);
            }
          } else if (event is String) {
            _processPath(event);
          }
        },
        onError: (err) => debugPrint('Native File Stream Error: $err'),
      );
    }

    // 2. Windows Cold Start CLI Arguments
    if (Platform.isWindows && initialArgs != null && initialArgs.isNotEmpty) {
      for (final arg in initialArgs) {
        _processPath(arg);
      }
    }
  }

  void addLink(String filePath) {
    _processPath(filePath);
  }

  void _processPath(String rawPath) {
    if (rawPath.isEmpty) return;

    String cleanPath = rawPath.trim();

    // Remove quote wrapping from Windows CLI
    if (cleanPath.startsWith('"') && cleanPath.endsWith('"')) {
      cleanPath = cleanPath.substring(1, cleanPath.length - 1);
    }

    // Convert file:// URIs (iOS/macOS AirDrop & file shares) to valid local file paths
    final uri = Uri.tryParse(cleanPath);
    if (uri != null && uri.isScheme('file')) {
      cleanPath = uri.toFilePath();
    } else if (cleanPath.startsWith('file://')) {
      cleanPath = Uri.decodeFull(cleanPath.replaceFirst('file://', ''));
    }

    // Normalize Windows path separators
    if (Platform.isWindows) {
      cleanPath = cleanPath.replaceAll('/', r'\');
    }

    if (_isAudioFile(cleanPath)) {
      debugPrint('Received local track path: $cleanPath');
      _linkStreamController.add(cleanPath);
    }
  }

  void dispose() {
    _fileSubscription?.cancel();
    _linkStreamController.close();
  }
}
