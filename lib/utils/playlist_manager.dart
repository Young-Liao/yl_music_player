import 'dart:ui' as ui;
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:metadata_god/metadata_god.dart';

/// Metadata model holding cached track details and compressed artwork bytes.
class TrackMetadataItem {
  final String filePath;
  final String title;
  final String artist;
  final Uint8List? compressedArtwork;

  TrackMetadataItem({
    required this.filePath,
    required this.title,
    required this.artist,
    this.compressedArtwork,
  });

  /// Factory constructor for unknown / empty track state.
  factory TrackMetadataItem.empty() {
    return TrackMetadataItem(
      filePath: "Unknown Path",
      title: "Unknown Title",
      artist: "Unknown Artist",
      compressedArtwork: null,
    );
  }

  /// Only file path
  factory TrackMetadataItem.onlyPath(String filePath) {
    return TrackMetadataItem(filePath: filePath, title: "", artist: "");
  }

  /// Synchronous fallback when metadata parsing fails or isn't ready yet.
  factory TrackMetadataItem.fallback(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    final cleanTitle = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    return TrackMetadataItem(
      filePath: path,
      title: cleanTitle,
      artist: 'Unknown Artist',
      compressedArtwork: null,
    );
  }

  /// Async factory method that reads ID3 tags via [MetadataGod] and compresses artwork.
  static Future<TrackMetadataItem> fromPath(String path) async {
    try {
      final metadata = await MetadataGod.readMetadata(file: path);

      final title =
          metadata.title ?? path.split('/').last.replaceAll('.mp3', '');
      final artist = metadata.artist ?? 'Unknown Artist';
      final rawArtwork = metadata.picture?.data;

      // Compress artwork byte array to 88x88 px thumbnail to save RAM and avoid render lag
      Uint8List? compressedArtwork;
      if (rawArtwork != null && rawArtwork.isNotEmpty) {
        compressedArtwork = await _compressImageBytes(
          rawArtwork,
          targetWidth: 88,
        );
      }

      return TrackMetadataItem(
        filePath: path,
        title: title,
        artist: artist,
        compressedArtwork: compressedArtwork,
      );
    } catch (e) {
      return TrackMetadataItem.fallback(path);
    }
  }

  /// Downscales high-resolution cover images to a thumbnail target width using Flutter UI codecs.
  static Future<Uint8List?> _compressImageBytes(
    Uint8List rawBytes, {
    required int targetWidth,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetWidth,
      );
      final frameInfo = await codec.getNextFrame();
      final image = frameInfo.image;
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      // Fallback to original raw bytes if codec compression fails
      return rawBytes;
    }
  }
}

/// Managing playlist persistence, LRU caching, window prefetching, and queue operations.
class PlaylistManager {
  final String jsonFilePath;
  final int maxCacheSize;

  List<String> _playlistPaths = [];
  int _currentIndex = 0;

  // Active scroll visibility window boundaries [L, R] inside the playlist panel.
  int _windowL = 0;
  int _windowR = 0;

  // LinkedHashMap maintains insertion order for true LRU eviction performance.
  final LinkedHashMap<String, TrackMetadataItem> _lruCache =
      LinkedHashMap<String, TrackMetadataItem>();

  PlaylistManager({
    required this.jsonFilePath,
    this.maxCacheSize =
        250, // Expanded cache limit to store more tracks in memory
  });

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  int get length => _playlistPaths.length;

  int get currentIndex => _currentIndex;

  List<String> get playlistPaths => List.unmodifiable(_playlistPaths);

  // ---------------------------------------------------------------------------
  // 1. Persistence & JSON Handling
  // ---------------------------------------------------------------------------

  Future<void> loadPlaylistFromJson() async {
    try {
      final file = File(jsonFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _playlistPaths = jsonList.cast<String>();
      } else {
        _playlistPaths = [];
      }
    } catch (e) {
      _playlistPaths = [];
    }
  }

  Future<void> savePlaylistToJson() async {
    try {
      final file = File(jsonFilePath);
      final jsonString = jsonEncode(_playlistPaths);
      await file.writeAsString(jsonString);
    } catch (e) {
      debugPrint('Error saving playlist to JSON: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 2. LRU Cache & Protected Window Eviction
  // ---------------------------------------------------------------------------

  /// Retrieves item from LRU cache without altering order during layout passes.
  TrackMetadataItem? _peekCache(String path) {
    return _lruCache[path];
  }

  /// Puts item into LRU cache. Ensures items currently inside active window [_windowL, _windowR]
  /// are protected and NEVER purged when capacity limit is reached.
  void _putToCache(String path, TrackMetadataItem metadata) {
    if (_lruCache.containsKey(path)) {
      _lruCache.remove(path);
    } else if (_lruCache.length >= maxCacheSize) {
      // Find oldest key NOT belonging to current active window
      final currentWindowPaths =
          (_windowL <= _windowR && _playlistPaths.isNotEmpty)
          ? _playlistPaths.sublist(_windowL, _windowR + 1).toSet()
          : <String>{};

      String? keyToEvict;
      for (final key in _lruCache.keys) {
        if (!currentWindowPaths.contains(key)) {
          keyToEvict = key;
          break;
        }
      }

      // If all cached items fall inside active window, evict first key anyway as emergency fallback
      keyToEvict ??= _lruCache.keys.first;
      _lruCache.remove(keyToEvict);
    }
    _lruCache[path] = metadata;
  }

  Future<TrackMetadataItem> _extractMetadata(String filePath) async {
    return await TrackMetadataItem.fromPath(filePath);
  }

  TrackMetadataItem _getSyncFallback(String path) {
    return TrackMetadataItem.fallback(path);
  }

  // ---------------------------------------------------------------------------
  // 3. Dynamic Scroll Window Updating [L, R]
  // ---------------------------------------------------------------------------

  /// Updates active window with an offset buffer of 10 items above and below visible range.
  Future<void> updateScrollWindow(
    int visibleStartIndex,
    int visibleEndIndex,
  ) async {
    if (_playlistPaths.isEmpty) return;

    // Buffer range: extend visible start/end by 10 items up & down
    const buffer = 10;
    _windowL = (visibleStartIndex - buffer).clamp(0, _playlistPaths.length - 1);
    _windowR = (visibleEndIndex + buffer).clamp(0, _playlistPaths.length - 1);

    // Identify paths within new window that lack metadata
    final uncachedPaths = <String>[];
    for (int i = _windowL; i <= _windowR; i++) {
      final path = _playlistPaths[i];
      if (!_lruCache.containsKey(path)) {
        uncachedPaths.add(path);
      }
    }

    if (uncachedPaths.isEmpty) return;

    // Concurrently fetch metadata for missing paths in window
    final results = await Future.wait(
      uncachedPaths.map((path) => _extractMetadata(path)),
    );

    for (int i = 0; i < uncachedPaths.length; i++) {
      _putToCache(uncachedPaths[i], results[i]);
    }
  }

  /// Synchronously returns cached metadata or fallback representation for list tile builders.
  TrackMetadataItem getCachedMetadataAtIndex(int index) {
    if (index < 0 || index >= _playlistPaths.length) {
      return TrackMetadataItem.empty();
    }
    final path = _playlistPaths[index];
    return _peekCache(path) ?? TrackMetadataItem.fallback(path);
  }

  // ---------------------------------------------------------------------------
  // 4. Track Controls & Queue State
  // ---------------------------------------------------------------------------

  Future<TrackMetadataItem?> getCurrentMetadata() async {
    if (_playlistPaths.isEmpty || _currentIndex >= _playlistPaths.length) {
      return null;
    }

    final currentPath = _playlistPaths[_currentIndex];
    if (_lruCache.containsKey(currentPath)) {
      return _peekCache(currentPath);
    }

    final metadata = await _extractMetadata(currentPath);
    _putToCache(currentPath, metadata);
    return metadata;
  }

  TrackMetadataItem? nextItem() {
    if (_playlistPaths.isEmpty) {
      _currentIndex = 0;
      return null;
    }
    _currentIndex = (_currentIndex + 1) % _playlistPaths.length;
    final path = _playlistPaths[_currentIndex];
    return _peekCache(path) ?? _getSyncFallback(path);
  }

  TrackMetadataItem? prevItem() {
    if (_playlistPaths.isEmpty) {
      _currentIndex = 0;
      return null;
    }
    _currentIndex = (_currentIndex - 1 + _playlistPaths.length) % _playlistPaths.length;
    final path = _playlistPaths[_currentIndex];
    return _peekCache(path) ?? _getSyncFallback(path);
  }

  // ---------------------------------------------------------------------------
  // 5. Playlist Modifications (Add, Delete, Move, Shuffle)
  // ---------------------------------------------------------------------------

  /// Immediately extracts metadata and caches item upon insertion.
  Future<void> addFileNextToCurrent(String filePath) async {
    final insertIndex = _playlistPaths.isEmpty ? 0 : _currentIndex + 1;
    _playlistPaths.insert(insertIndex, filePath);

    // Warm metadata cache immediately
    final metadata = await _extractMetadata(filePath);
    _putToCache(filePath, metadata);

    await savePlaylistToJson();
  }

  /// Delete Item and return whether it is current track.
  Future<bool> deleteItem(int index) async {
    if (index < 0 || index >= _playlistPaths.length) return false;

    final pathToRemove = _playlistPaths[index];
    _playlistPaths.removeAt(index);
    _lruCache.remove(pathToRemove);

    bool isCurrent = false;

    if (_playlistPaths.isEmpty) {
      _currentIndex = 0;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      // If deleted current track, clamp index to valid bounds
      if (_currentIndex >= _playlistPaths.length) {
        _currentIndex = _playlistPaths.length - 1;
      }
      isCurrent = true;
    }

    await savePlaylistToJson();

    return isCurrent;
  }

  Future<void> moveItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playlistPaths.length) return;

    // ReorderableList passes target insertion index up to list length
    if (newIndex < 0 || newIndex > _playlistPaths.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex == newIndex) return;

    final item = _playlistPaths.removeAt(oldIndex);
    _playlistPaths.insert(newIndex, item);

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    await savePlaylistToJson();
  }

  /// Shuffles playlist and updates metadata for new top viewport window immediately.
  Future<void> shufflePlaylist() async {
    if (_playlistPaths.length <= 1) return;

    final currentTrackPath = _playlistPaths[_currentIndex];
    _playlistPaths.shuffle();
    _currentIndex = _playlistPaths.indexOf(currentTrackPath);

    // Reload active window immediately after shuffle
    await updateScrollWindow(0, 20);
    await savePlaylistToJson();
  }

  void updateCurrentIndexWithPath(String filePath) =>
      _currentIndex = _playlistPaths.indexOf(filePath);
}
