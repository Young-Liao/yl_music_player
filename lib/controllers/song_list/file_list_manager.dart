import 'dart:async';

import 'package:yl_music_player/controllers/song_list/song_list_managers.dart';

import '../../utils/data_structures/track_metadata_item.dart';

enum FileListSortOption {
  title('Title'),
  author('Author'),
  album('Album');

  final String label;
  const FileListSortOption(this.label);
}

/// Manages full track library, persisted to `file_list` table.
class FileListManager extends SongListManager {
  FileListManager({required super.db, super.maxCacheSize = 250});

  FileListSortOption _currentSort = FileListSortOption.title;
  FileListSortOption get currentSort => _currentSort;

  Timer? _debounceTimer;

  @override
  Future<void> loadListFromDb({
    Future<void> Function(String filePath)? onSongReady,
  }) async {
    if (db == null) return;

    final items = await db!.loadFileList();
    privateSongPaths.clear();

    for (final item in items) {
      privateSongPaths.add(item.filePath);
      putToCache(item.filePath, item);
    }

    _sortTracks();

    if (privateSongPaths.isNotEmpty && onSongReady != null) {
      onSongReady(privateSongPaths.first);
    }
  }

  @override
  Future<void> saveListToDb() async {
    if (db == null) return;

    final List<TrackMetadataItem> items = [];
    for (final path in privateSongPaths) {
      final cached = peekCache(path) ?? getSyncFallback(path);
      items.add(cached);
    }

    await db!.saveFileList(items);
  }

  void setSortOption(FileListSortOption sortOption) {
    _currentSort = sortOption;
    _sortTracks();
  }

  void _sortTracks() {
    if (privateSongPaths.isEmpty) return;

    privateSongPaths.sort((pathA, pathB) {
      final metaA = peekCache(pathA) ?? getSyncFallback(pathA);
      final metaB = peekCache(pathB) ?? getSyncFallback(pathB);

      switch (_currentSort) {
        case FileListSortOption.title:
          return metaA.title.toLowerCase().compareTo(metaB.title.toLowerCase());
        case FileListSortOption.author:
          return metaA.artist.toLowerCase().compareTo(metaB.artist.toLowerCase());
        case FileListSortOption.album:
          return metaA.album.toLowerCase().compareTo(metaB.album.toLowerCase());
      }
    });

    _scheduleDbSave();
  }

  @override
  Future<void> addFileAt(String filePath, int targetIndex) async {
    await super.addFileAt(filePath, targetIndex);
    _scheduleDbSave();
  }

  @override
  Future<bool> deleteItem(int index) async {
    final result = await super.deleteItem(index);
    if (result) {
      _scheduleDbSave();
    }
    return result;
  }

  @override
  Future<void> moveItem(int oldIndex, int newIndex) async {
    await super.moveItem(oldIndex, newIndex);
    _scheduleDbSave();
  }

  void _scheduleDbSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await saveListToDb();
    });
  }
}
