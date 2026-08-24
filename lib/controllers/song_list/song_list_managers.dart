import 'dart:collection';

import '../../utils/data_structures/track_metadata_item.dart';
import '../../utils/storage/database/interface.dart';

/// Base manager handling song collection, LRU caching, and dynamic scroll window prefetching.
class SongListManager {
  final IDatabaseStorage db;
  final int maxCacheSize;

  List<String> privateSongPaths = [];
  int _windowL = 0;
  int _windowR = 0;

  final LinkedHashMap<String, TrackMetadataItem> lruCache =
  LinkedHashMap<String, TrackMetadataItem>();

  SongListManager({required this.db, this.maxCacheSize = 250});

  // Getters
  int get length => privateSongPaths.length;
  List<String> get songPaths => List.unmodifiable(privateSongPaths);

  // Persistence
  Future<void> loadListFromDb() async {
    privateSongPaths = await db.loadPlaylist();
    final cachedData = await db.loadAllCachedMetadata();
    cachedData.forEach((path, metadata) {
      if (privateSongPaths.contains(path)) {
        putToCache(path, metadata);
      }
    });
  }

  Future<void> saveListToDb() async {
    await db.savePlaylist(privateSongPaths);
  }

  // LRU Caching
  TrackMetadataItem? peekCache(String path) => lruCache[path];

  void putToCache(String path, TrackMetadataItem metadata) {
    if (lruCache.containsKey(path)) {
      lruCache.remove(path);
    } else if (lruCache.length >= maxCacheSize) {
      final currentWindowPaths =
      (_windowL <= _windowR && privateSongPaths.isNotEmpty)
          ? privateSongPaths.sublist(_windowL, _windowR + 1).toSet()
          : <String>{};

      String? keyToEvict;
      for (final key in lruCache.keys) {
        if (!currentWindowPaths.contains(key)) {
          keyToEvict = key;
          break;
        }
      }

      keyToEvict ??= lruCache.keys.first;
      lruCache.remove(keyToEvict);
    }
    lruCache[path] = metadata;
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
    if (privateSongPaths.isEmpty) return;

    const buffer = 10;
    _windowL = (visibleStartIndex - buffer).clamp(0, privateSongPaths.length - 1);
    _windowR = (visibleEndIndex + buffer).clamp(0, privateSongPaths.length - 1);

    final uncachedPaths = <String>[];
    for (int i = _windowL; i <= _windowR; i++) {
      final path = privateSongPaths[i];
      if (!lruCache.containsKey(path)) {
        uncachedPaths.add(path);
      }
    }

    if (uncachedPaths.isEmpty) return;

    final results = await Future.wait(
      uncachedPaths.map((path) => extractMetadata(path)),
    );

    for (int i = 0; i < uncachedPaths.length; i++) {
      putToCache(uncachedPaths[i], results[i]);
    }
  }

  TrackMetadataItem getCachedMetadataAtIndex(int index) {
    if (index < 0 || index >= privateSongPaths.length) {
      return TrackMetadataItem.empty();
    }
    final path = privateSongPaths[index];
    return peekCache(path) ?? TrackMetadataItem.fallback(path);
  }

  // Generic List Operations
  Future<void> addFileAt(String filePath, int targetIndex) async {
    final existingIndex = privateSongPaths.indexOf(filePath);

    if (existingIndex != -1) {
      if (existingIndex == targetIndex) return;
      await moveItem(existingIndex, targetIndex);
    } else {
      final insertIdx = targetIndex.clamp(0, privateSongPaths.length);
      privateSongPaths.insert(insertIdx, filePath);

      final metadata = await extractMetadata(filePath);
      putToCache(filePath, metadata);

      await saveListToDb();
    }
  }

  Future<bool> deleteItem(int index) async {
    if (index < 0 || index >= privateSongPaths.length) return false;

    final pathToRemove = privateSongPaths[index];
    privateSongPaths.removeAt(index);
    lruCache.remove(pathToRemove);

    await saveListToDb();
    return true;
  }

  Future<void> moveItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= privateSongPaths.length) return;
    if (newIndex < 0 || newIndex > privateSongPaths.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (oldIndex == newIndex) return;

    final item = privateSongPaths.removeAt(oldIndex);
    privateSongPaths.insert(newIndex, item);

    await saveListToDb();
  }

  List<int> search(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    final matches = <int>[];

    for (int i = 0; i < privateSongPaths.length; i++) {
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
