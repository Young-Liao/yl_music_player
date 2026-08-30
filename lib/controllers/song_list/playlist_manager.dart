import 'dart:async';
import 'package:yl_music_player/controllers/song_list/song_list_managers.dart';

import '../../utils/data_structures/track_metadata_item.dart';
import '../../utils/storage/settings.dart';

/// Manages active playback queue, persisted to `current_playlist` table.
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
    if (db == null) return;

    final loadedPaths = await db!.loadPlaylist();
    privateSongPaths.clear();
    privateSongPaths.addAll(loadedPaths);

    if (songPaths.isNotEmpty && onSongReady != null) {
      final currentPath = songPaths[_currentIndex.clamp(0, songPaths.length - 1)];
      onSongReady(currentPath);
    }
  }

  @override
  Future<void> saveListToDb() async {
    if (db == null) return;
    await db!.savePlaylist(privateSongPaths);
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
    putToCache(currentPath, metadata);
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
    await saveListToDb();
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
    await saveListToDb();
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
    await saveListToDb();
  }

  Future<void> shufflePlaylist() async {
    if (songPaths.length <= 1) return;

    final currentTrackPath = songPaths[_currentIndex];
    privateSongPaths.shuffle();
    _currentIndex = privateSongPaths.indexOf(currentTrackPath);
    saveCurrentIndex();

    await updateScrollWindow(0, 20);
    await saveListToDb();
  }

  void updateCurrentIndexWithPath(String filePath) {
    _currentIndex = songPaths.indexOf(filePath);
    saveCurrentIndex();
  }
}

