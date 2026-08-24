import 'dart:async';
import 'package:yl_music_player/controllers/song_list/song_list_managers.dart';

enum FileListSortOption {
  duration('Duration'),
  title('Title'),
  author('Author'),
  album('Album');

  final String label;

  const FileListSortOption(this.label);
}

class FileListManager extends SongListManager {
  FileListManager({required super.db, super.maxCacheSize = 250});

  FileListSortOption _currentSort = FileListSortOption.duration;
  FileListSortOption get currentSort => _currentSort;

  Timer? _debounceTimer;

  /// Loads playlist paths from the database and initializes mock tracks if empty.
  @override
  Future<void> loadListFromDb({
    Future<void> Function(String filePath)? onSongReady,
  }) async {
    await super.loadListFromDb();

    // Apply the active sorting rule to privateSongPaths
    _sortTracks();

    if (privateSongPaths.isNotEmpty && onSongReady != null) {
      onSongReady(privateSongPaths.first);
    }
  }

  void setSortOption(FileListSortOption sortOption) {
    _currentSort = sortOption;
    _sortTracks();
  }

  void _sortTracks() {
    if (privateSongPaths.isEmpty) return;

    privateSongPaths.sort((pathA, pathB) {
      final metaA = getCachedMetadataAtIndex(privateSongPaths.indexOf(pathA));
      final metaB = getCachedMetadataAtIndex(privateSongPaths.indexOf(pathB));

      switch (_currentSort) {
        case FileListSortOption.duration:
          return metaA.duration.compareTo(metaB.duration);
        case FileListSortOption.title:
          return metaA.title.toLowerCase().compareTo(metaB.title.toLowerCase());
        case FileListSortOption.author:
          return metaA.artist.toLowerCase().compareTo(metaB.artist.toLowerCase());
        case FileListSortOption.album:
          return metaA.album.toLowerCase().compareTo(metaB.album.toLowerCase());
      }
    });

    // Automatically trigger database save after sorting
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