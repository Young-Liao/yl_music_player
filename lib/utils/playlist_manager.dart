import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
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

  /// Async factory method that reads ID3 tags via MetadataGod.
  static Future<TrackMetadataItem> fromPath(String path) async {
    try {
      // Async metadata read using MetadataGod
      final metadata = await MetadataGod.readMetadata(file: path);
      debugPrint('path: $path');

      final title = metadata.title ?? path.split('/').last.replaceAll('.mp3', '');
      final artist = metadata.artist ?? 'Unknown Artist';
      final artworkBytes = metadata.picture?.data; // Extract cover art bytes
      debugPrint('title: $title');

      return TrackMetadataItem(
        filePath: path,
        title: title,
        artist: artist,
        // Optional: Extract artwork bytes directly if available in MetadataGod payload
        compressedArtwork: artworkBytes,
      );
    } catch (e) {
      // Fallback gracefully to basic file name parsing if reading fails
      return TrackMetadataItem.fallback(path);
    }
  }
}

/// Managing playlist persistence, LRU caching, window prefetching, and queue operations.
class PlaylistManager {
  // Path to the local JSON file where playlist paths are persisted.
  final String jsonFilePath;

  // Maximum capacity of items allowed in memory at any time.
  final int maxCacheSize;

  // List of file paths representing the master playlist order.
  List<String> _playlistPaths = [];

  // Pointer tracking the index of the currently active track.
  int _currentIndex = 0;

  // Active scroll visibility window boundaries [L, R] inside the playlist panel.
  int _windowL = 0;
  int _windowR = 0;

  // LRU Cache mapping file paths to TrackMetadata.
  // LinkedHashMap maintains insertion order; moving accessed items to the end simulates LRU.
  final LinkedHashMap<String, TrackMetadataItem> _lruCache = LinkedHashMap<String, TrackMetadataItem>();

  PlaylistManager({
    required this.jsonFilePath,
    this.maxCacheSize = 50,
  });

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// Returns total items in playlist.
  int get length => _playlistPaths.length;

  /// Returns current playing track index.
  int get currentIndex => _currentIndex;

  /// Returns unmodifiable view of current file paths.
  List<String> get playlistPaths => List.unmodifiable(_playlistPaths);

  // ---------------------------------------------------------------------------
  // 1. Persistence & JSON Handling
  // ---------------------------------------------------------------------------

  /// Loads playlist configuration from local JSON file.
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

  /// Saves current file path list to local JSON file.
  Future<void> savePlaylistToJson() async {
    try {
      final file = File(jsonFilePath);
      final jsonString = jsonEncode(_playlistPaths);
      await file.writeAsString(jsonString);
    } catch (e) {
      // Handle file write permissions or disk issues here
    }
  }

  // ---------------------------------------------------------------------------
  // 2. LRU Cache & Background Prefetching
  // ---------------------------------------------------------------------------

  /// Retrieves item from LRU cache. Refreshes its position as 'most recently used'.
  TrackMetadataItem? _getFromCache(String path) {
    if (!_lruCache.containsKey(path)) return null;

    // Refresh access order in LinkedHashMap
    final value = _lruCache.remove(path)!;
    _lruCache[path] = value;
    return value;
  }

  /// Puts item into LRU cache. Evicts oldest entries if capacity exceeded.
  void _putToCache(String path, TrackMetadataItem metadata) {
    if (_lruCache.containsKey(path)) {
      _lruCache.remove(path);
    } else if (_lruCache.length >= maxCacheSize) {
      // Evict the least recently used item (first key in LinkedHashMap)
      final oldestKey = _lruCache.keys.first;
      _lruCache.remove(oldestKey);
    }
    _lruCache[path] = metadata;
  }

  /// Extract actual audio metadata asynchronously via MetadataGod.
  Future<TrackMetadataItem> _extractMetadata(String filePath) async {
    // Calls static async method created above
    return await TrackMetadataItem.fromPath(filePath);
  }

  /// Fast synchronous fallback for instant UI return when cache misses
  TrackMetadataItem _getSyncFallback(String path) {
    return TrackMetadataItem.fallback(path);
  }

  // ---------------------------------------------------------------------------
  // 3. Dynamic Scroll Window Updating [L, R]
  // ---------------------------------------------------------------------------

  /// Updates target scroll window [L, R] according to top/bottom visible indices in UI.
  /// Trigger this method inside a ScrollController listener from your playlist UI.
  Future<void> updateScrollWindow(int visibleStartIndex, int visibleEndIndex) async {
    if (_playlistPaths.isEmpty) return;

    // Buffer range outside visible UI to pre-load adjacent items smoothly
    const buffer = 5;
    _windowL = (visibleStartIndex - buffer).clamp(0, _playlistPaths.length - 1);
    _windowR = (visibleEndIndex + buffer).clamp(0, _playlistPaths.length - 1);

    // 1. Evict cache entries that fall completely outside [_windowL, _windowR]
    final allowedPaths = _playlistPaths.sublist(_windowL, _windowR + 1).toSet();
    _lruCache.removeWhere((path, _) => !allowedPaths.contains(path));

    // 2. Load missing metadata in background for items within new range
    for (int i = _windowL; i <= _windowR; i++) {
      final path = _playlistPaths[i];
      if (!_lruCache.containsKey(path)) {
        // Asynchronously extract and populate cache without blocking main scroll thread
        _extractMetadata(path).then((metadata) {
          _putToCache(path, metadata);
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 4. Track Controls & Querying (For Audio Controller)
  // ---------------------------------------------------------------------------

  /// Returns current active track's metadata. Evaluates cache or generates fallback immediately.
  Future<TrackMetadataItem?> getCurrentMetadata() async {
    if (_playlistPaths.isEmpty || _currentIndex >= _playlistPaths.length) {
      return null;
    }

    final currentPath = _playlistPaths[_currentIndex];

    // Return cached metadata if present
    if (_lruCache.containsKey(currentPath)) {
      return _getFromCache(currentPath);
    }

    // Otherwise extract, cache, and return
    final metadata = await _extractMetadata(currentPath);
    _putToCache(currentPath, metadata);
    return metadata;
  }

  /// Advances to next item index in list.
  TrackMetadataItem? nextItem() {
    if (_playlistPaths.isEmpty) return null;
    _currentIndex = (_currentIndex + 1) % _playlistPaths.length;
    final path = _playlistPaths[_currentIndex];

    // Returns cached version or synchronous basic fallback immediately
    return _getFromCache(path) ?? _getSyncFallback(path);
  }

  /// Moves back to previous item index in list.
  TrackMetadataItem? prevItem() {
    if (_playlistPaths.isEmpty) return null;
    _currentIndex = (_currentIndex - 1 + _playlistPaths.length) % _playlistPaths.length;
    final path = _playlistPaths[_currentIndex];

    return _getFromCache(path) ?? _getSyncFallback(path);
  }

  // ---------------------------------------------------------------------------
  // 5. Playlist Modifications (Add, Delete, Move, Shuffle)
  // ---------------------------------------------------------------------------

  /// Adds a new audio file path directly NEXT to the current playing item index.
  Future<void> addFileNextToCurrent(String filePath) async {
    final insertIndex = _playlistPaths.isEmpty ? 0 : _currentIndex + 1;
    _playlistPaths.insert(insertIndex, filePath);

    // Warm up metadata extraction immediately for newly added file
    final metadata = await _extractMetadata(filePath);
    _putToCache(filePath, metadata);

    await savePlaylistToJson();
  }

  /// Deletes item at index, adjusts pointers, purges cache, and saves state.
  Future<void> deleteItem(int index) async {
    if (index < 0 || index >= _playlistPaths.length) return;

    final pathToRemove = _playlistPaths[index];
    _playlistPaths.removeAt(index);
    _lruCache.remove(pathToRemove);

    // Adjust current playing index pointer
    if (index < _currentIndex) {
      _currentIndex--;
    } else if (_currentIndex >= _playlistPaths.length && _playlistPaths.isNotEmpty) {
      _currentIndex = _playlistPaths.length - 1;
    }

    await savePlaylistToJson();
  }

  /// Reorders item position from [oldIndex] to [newIndex] (e.g., drag-and-drop UI).
  Future<void> moveItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _playlistPaths.length) return;
    if (newIndex < 0 || newIndex >= _playlistPaths.length) return;

    // Standard reordering logic adjusting index offset when moving downwards
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = _playlistPaths.removeAt(oldIndex);
    _playlistPaths.insert(newIndex, item);

    // Synchronize active tracking pointer
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }

    await savePlaylistToJson();
  }

  /// Shuffles playlist order, retains currently playing track, re-populates cache.
  Future<void> shufflePlaylist() async {
    if (_playlistPaths.length <= 1) return;

    final currentTrackPath = _playlistPaths[_currentIndex];

    // Shuffle the list
    _playlistPaths.shuffle();

    // Reset current index pointer to new index of original track
    _currentIndex = _playlistPaths.indexOf(currentTrackPath);

    // Clear outdated spatial cache order and rebuild for current window
    _lruCache.clear();
    await updateScrollWindow(_currentIndex, _currentIndex + 5);
    await savePlaylistToJson();
  }
}