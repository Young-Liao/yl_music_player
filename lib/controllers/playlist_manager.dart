import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:yl_music_player/utils/storage/settings.dart';

import '../utils/data_structures/track_metadata_item.dart';
import '../utils/storage/database/interface.dart';

/// Managing playlist persistence, LRU caching, window prefetching, and queue operations.
class PlaylistManager {
  final IDatabaseStorage db;
  final int maxCacheSize;

  List<String> _playlistPaths = [];
  int _currentIndex = 0;
  int _windowL = 0;
  int _windowR = 0;

  final LinkedHashMap<String, TrackMetadataItem> _lruCache =
      LinkedHashMap<String, TrackMetadataItem>();

  PlaylistManager({required this.db, this.maxCacheSize = 250})
    : _currentIndex = SettingsStorage.instance.lastTrackIndex {
    debugPrint(
      "Settings Storage lastTrackIndex: ${SettingsStorage.instance.lastTrackIndex}",
    );
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  int get length => _playlistPaths.length;

  int get currentIndex => _currentIndex;

  List<String> get playlistPaths => List.unmodifiable(_playlistPaths);

  // ---------------------------------------------------------------------------
  // 1. Persistence
  // ---------------------------------------------------------------------------

  // Load playlist & pre-populate LRU cache directly from SQLite DB
  Future<void> loadPlaylistFromDb({
    Future<void> Function(String filePath)? onSongReady,
  }) async {
    _playlistPaths = await db.loadPlaylist();

    // Warm up LRU Cache with existing database records
    final cachedData = await db.loadAllCachedMetadata();
    cachedData.forEach((path, metadata) {
      if (_playlistPaths.contains(path)) {
        _putToCache(path, metadata);
      }
    });

    if (_playlistPaths.isNotEmpty && onSongReady != null) {
      final currentPath = _playlistPaths[_currentIndex];
      await onSongReady(currentPath);
    }
  }

  Future<void> savePlaylistToDb() async {
    await db.savePlaylist(_playlistPaths);
  }

  void saveCurrentIndex() =>
      SettingsStorage.instance.setLastTrackIndex(_currentIndex);

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

      keyToEvict ??= _lruCache.keys.first;
      _lruCache.remove(keyToEvict);
    }
    _lruCache[path] = metadata;

    // Persist parsed metadata to DB asynchronously
    db.saveCachedMetadata(metadata);
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
      saveCurrentIndex();
      return null;
    }
    _currentIndex = (_currentIndex + 1) % _playlistPaths.length;
    final path = _playlistPaths[_currentIndex];
    saveCurrentIndex();
    return _peekCache(path) ?? _getSyncFallback(path);
  }

  TrackMetadataItem? prevItem() {
    if (_playlistPaths.isEmpty) {
      _currentIndex = 0;
      saveCurrentIndex();
      return null;
    }
    _currentIndex =
        (_currentIndex - 1 + _playlistPaths.length) % _playlistPaths.length;
    final path = _playlistPaths[_currentIndex];
    saveCurrentIndex();
    return _peekCache(path) ?? _getSyncFallback(path);
  }

  // ---------------------------------------------------------------------------
  // 5. Playlist Modifications (Add, Delete, Move, Shuffle)
  // ---------------------------------------------------------------------------

  /// Immediately extracts metadata and caches item upon insertion.
  /// Adds a track next to the currently playing item.
  /// If the file already exists in the playlist, moves it next to current instead.
  Future<void> addFileNextToCurrent(String filePath) async {
    final existingIndex = _playlistPaths.indexOf(filePath);

    if (existingIndex != -1) {
      // 1. Target track already exists: perform relocation next to current track
      final targetIndex = _playlistPaths.isEmpty ? 0 : _currentIndex + 1;

      // Avoid unnecessary move if it's already in the target position
      if (existingIndex == targetIndex ||
          (_currentIndex == existingIndex && _playlistPaths.length == 1)) {
        return;
      }

      await moveItem(existingIndex, targetIndex);
    } else {
      // 2. Target track is new: insert next to current track
      final insertIndex = _playlistPaths.isEmpty ? 0 : _currentIndex + 1;
      _playlistPaths.insert(insertIndex, filePath);

      // Warm metadata cache immediately
      final metadata = await _extractMetadata(filePath);
      _putToCache(filePath, metadata);

      await savePlaylistToDb();
    }
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

    saveCurrentIndex();
    await savePlaylistToDb();

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

    saveCurrentIndex();
    await savePlaylistToDb();
  }

  /// Shuffles playlist and updates metadata for new top viewport window immediately.
  Future<void> shufflePlaylist() async {
    if (_playlistPaths.length <= 1) return;

    final currentTrackPath = _playlistPaths[_currentIndex];
    _playlistPaths.shuffle();
    _currentIndex = _playlistPaths.indexOf(currentTrackPath);
    saveCurrentIndex();

    // Reload active window immediately after shuffle
    await updateScrollWindow(0, 20);
    await savePlaylistToDb();
  }

  void updateCurrentIndexWithPath(String filePath) {
    _currentIndex = _playlistPaths.indexOf(filePath);
    saveCurrentIndex();
  }
}
