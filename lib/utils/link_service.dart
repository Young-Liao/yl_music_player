import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LinkService {
  static final LinkService instance = LinkService._();
  LinkService._();

  // Matched exact channel name string with AppDelegate.swift
  static const _eventChannel = EventChannel('com.youngl.ylmusic/file_stream');
  final StreamController<String> _linkStreamController = StreamController<String>.broadcast();
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
    // 1. macOS Native AppleEvent Stream (Cold Start & Runtime)
    if (Platform.isMacOS) {
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
        if (File(arg).existsSync()) {
          _processPath(arg);
        }
      }
    }
  }

  void addLink(String filePath) {
    _processPath(filePath);
  }

  void _processPath(String filePath) {
    if (_isAudioFile(filePath)) {
      debugPrint('Received local track path: $filePath');
      _linkStreamController.add(filePath);
    }
  }

  void dispose() {
    _fileSubscription?.cancel();
    _linkStreamController.close();
  }
}
