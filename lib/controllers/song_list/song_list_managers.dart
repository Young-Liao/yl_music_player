import 'dart:collection';

import '../../utils/data_structures/track_metadata_item.dart';
import '../../utils/storage/database/interface.dart';
import '../../utils/storage/settings.dart';

/// Base manager handling song collection, LRU caching, and dynamic scroll window prefetching.
class SongListManager {
  final IDatabaseStorage db;
  final int maxCacheSize;

  List<String> _songPaths = [];
  int _windowL = 0;
  int _windowR = 0;

  final LinkedHashMap<String, TrackMetadataItem> _lruCache =
  LinkedHashMap<String, TrackMetadataItem>();

  SongListManager({required this.db, this.maxCacheSize = 250});

  // Getters
  int get length => _songPaths.length;
  List<String> get songPaths => List.unmodifiable(_songPaths);

  // Persistence
  Future<void> loadListFromDb() async {
    _songPaths = await db.loadPlaylist();
    final cachedData = await db.loadAllCachedMetadata();
    cachedData.forEach((path, metadata) {
      if (_songPaths.contains(path)) {
        _putToCache(path, metadata);
      }
    });
  }

  Future<void> saveListToDb() async {
    await db.savePlaylist(_songPaths);
  }

  // LRU Caching
  TrackMetadataItem? peekCache(String path) => _lruCache[path];

  void _putToCache(String path, TrackMetadataItem metadata) {
    if (_lruCache.containsKey(path)) {
      _lruCache.remove(path);
    } else if (_lruCache.length >= maxCacheSize) {
      final currentWindowPaths =
      (_windowL <= _windowR && _songPaths.isNotEmpty)
          ? _songPaths.sublist(_windowL, _windowR + 1).toSet()
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
    db.saveCachedMetadata(metadata);
  }

  Future<TrackMetadataItem> extractMetadata(String filePath) async {
    return await TrackMetadataItem.fromPath(filePath);
  }

  TrackMetadataItem getSyncFallback(String path) {
    return TrackMetadataItem.fallback(path);
  }

  // Dynamic Scroll Window
  Future<void> updateScrollWindow(
      int visibleStartIndex,
      int visibleEndIndex,
      ) async {
    if (_songPaths.isEmpty) return;

    const buffer = 10;
    _windowL = (visibleStartIndex - buffer).clamp(0, _songPaths.length - 1);
    _windowR = (visibleEndIndex + buffer).clamp(0, _songPaths.length - 1);

    final uncachedPaths = <String>[];
    for (int i = _windowL; i <= _windowR; i++) {
      final path = _songPaths[i];
      if (!_lruCache.containsKey(path)) {
        uncachedPaths.add(path);
      }
    }

    if (uncachedPaths.isEmpty) return;

    final results = await Future.wait(
      uncachedPaths.map((path) => extractMetadata(path)),
    );

    for (int i = 0; i < uncachedPaths.length; i++) {
      _putToCache(uncachedPaths[i], results[i]);
    }
  }

  TrackMetadataItem getCachedMetadataAtIndex(int index) {
    if (index < 0 || index >= _songPaths.length) {
      return TrackMetadataItem.empty();
    }
    final path = _songPaths[index];
    return peekCache(path) ?? TrackMetadataItem.fallback(path);
  }

  // Generic List Operations
  Future<void> addFileAt(String filePath, int targetIndex) async {
    final existingIndex = _songPaths.indexOf(filePath);

    if (existingIndex != -1) {
      if (existingIndex == targetIndex) return;
      await moveItem(existingIndex, targetIndex);
    } else {
      final insertIdx = targetIndex.clamp(0, _songPaths.length);
      _songPaths.insert(insertIdx, filePath);

      final metadata = await extractMetadata(filePath);
      _putToCache(filePath, metadata);

      await saveListToDb();
    }
  }

  Future<bool> deleteItem(int index) async {
    if (index < 0 || index >= _songPaths.length) return false;

    final pathToRemove = _songPaths[index];
    _songPaths.removeAt(index);
    _lruCache.remove(pathToRemove);

    await saveListToDb();
    return true;
  }

  Future<void> moveItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _songPaths.length) return;
    if (newIndex < 0 || newIndex > _songPaths.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex == newIndex) return;

    final item = _songPaths.removeAt(oldIndex);
    _songPaths.insert(newIndex, item);

    await saveListToDb();
  }

  List<int> search(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    final matches = <int>[];

    for (int i = 0; i < _songPaths.length; i++) {
      final meta = getCachedMetadataAtIndex(i);
      if (meta.title.toLowerCase().contains(lowerQuery) ||
          meta.artist.toLowerCase().contains(lowerQuery) ||
          meta.filePath.toLowerCase().contains(lowerQuery)) {
        matches.add(i);
      }
    }
    return matches;
  }
}

/// Specialized Manager handling queue state, currently playing pointers, and playback operations.
class PlaylistManager extends SongListManager {
  int _currentIndex = 0;

  PlaylistManager({required super.db, super.maxCacheSize = 250})
      : _currentIndex = SettingsStorage.instance.lastTrackIndex;

  int get currentIndex => _currentIndex;
  List<String> get playlistPaths => songPaths;

  @override
  Future<void> loadListFromDb({
    Future<void> Function(String filePath)? onSongReady,
  }) async {
    await super.loadListFromDb();
    if (songPaths.isNotEmpty && onSongReady != null) {
      final currentPath = songPaths[_currentIndex.clamp(0, songPaths.length - 1)];
      onSongReady(currentPath);
    }
  }

  void saveCurrentIndex() =>
      SettingsStorage.instance.setLastTrackIndex(_currentIndex);

  Future<TrackMetadataItem?> getCurrentMetadata() async {
    if (songPaths.isEmpty || _currentIndex >= songPaths.length) {
      return null;
    }

    final currentPath = songPaths[_currentIndex];
    if (peekCache(currentPath) != null) {
      return peekCache(currentPath);
    }

    final metadata = await extractMetadata(currentPath);
    _putToCache(currentPath, metadata);
    return metadata;
  }

  TrackMetadataItem? nextItem() {
    if (songPaths.isEmpty) {
      _currentIndex = 0;
      saveCurrentIndex();
      return null;
    }
    _currentIndex = (_currentIndex + 1) % songPaths.length;
    final path = songPaths[_currentIndex];
    saveCurrentIndex();
    return peekCache(path) ?? getSyncFallback(path);
  }

  TrackMetadataItem? prevItem() {
    if (songPaths.isEmpty) {
      _currentIndex = 0;
      saveCurrentIndex();
      return null;
    }
    _currentIndex =
        (_currentIndex - 1 + songPaths.length) % songPaths.length;
    final path = songPaths[_currentIndex];
    saveCurrentIndex();
    return peekCache(path) ?? getSyncFallback(path);
  }

  Future<void> addFileNextToCurrent(String filePath) async {
    final targetIndex = songPaths.isEmpty ? 0 : _currentIndex + 1;
    await addFileAt(filePath, targetIndex);
  }

  @override
  Future<bool> deleteItem(int index) async {
    final isCurrent = (index == _currentIndex);

    await super.deleteItem(index);

    if (songPaths.isEmpty) {
      _currentIndex = 0;
    } else if (index < _currentIndex) {
      _currentIndex--;
    } else if (index == _currentIndex) {
      if (_currentIndex >= songPaths.length) {
        _currentIndex = songPaths.length - 1;
      }
    }

    saveCurrentIndex();
    return isCurrent;
  }

  @override
  Future<void> moveItem(int oldIndex, int newIndex) async {
    final adjustedNewIndex = (oldIndex < newIndex) ? newIndex - 1 : newIndex;

    await super.moveItem(oldIndex, newIndex);

    if (_currentIndex == oldIndex) {
      _currentIndex = adjustedNewIndex;
    } else if (oldIndex < _currentIndex && adjustedNewIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && adjustedNewIndex <= _currentIndex) {
      _currentIndex++;
    }

    saveCurrentIndex();
  }

  Future<void> shufflePlaylist() async {
    if (songPaths.length <= 1) return;

    final currentTrackPath = songPaths[_currentIndex];
    _songPaths.shuffle();
    _currentIndex = _songPaths.indexOf(currentTrackPath);
    saveCurrentIndex();

    await updateScrollWindow(0, 20);
    await saveListToDb();
  }

  void updateCurrentIndexWithPath(String filePath) {
    _currentIndex = songPaths.indexOf(filePath);
    saveCurrentIndex();
  }
}
