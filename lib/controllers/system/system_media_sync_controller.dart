import 'dart:typed_data';

import '../../main.dart';
import '../../utils/file/artwork_cache_manager.dart';
import '../lyrics/lyrics_handler.dart';

/// Handles synchronization between in-app playback state/lyrics and native system OS controls.
class SystemMediaSyncController {
  static String? _lastLyricLine;
  static String? _lastSongId;
  static bool? _lastPlayState;

  /// Synchronizes current playback state, artwork, and active lyric line with the system lockscreen/control center.
  /// Call this inside [LyricsView] build/post-frame callbacks or playback state update listeners.
  static Future<void> sync({
    required String songId,
    required String title,
    required String artist,
    required Uint8List? artworkBytes,
    required Duration position,
    required Duration duration,
    required bool isPlaying,
    required LyricsHandler lyricsHandler,
  }) async {
    // 1. Resolve current active lyric line
    final activeIndices = lyricsHandler.getCurrentIndices(position);
    final String? currentLyric = activeIndices.isNotEmpty
        ? lyricsHandler.lines[activeIndices.first].text
        : null;

    // 2. Evaluate state delta triggers
    final bool isTrackChanged = _lastSongId != songId;
    final bool isLyricChanged = _lastLyricLine != currentLyric;
    final bool isStateChanged = _lastPlayState != isPlaying;

    // Only hit system IPC bridge when metadata or playback state actually changes
    if (isTrackChanged || isLyricChanged || isStateChanged) {
      _lastSongId = songId;
      _lastLyricLine = currentLyric;
      _lastPlayState = isPlaying;

      // Thread-safe asynchronous conversion of cover art bytes to local URI
      final Uri? artworkUri = await ArtworkCacheManager.getUriFromBytes(songId, artworkBytes);

      // Dispatch update to system AudioHandler
      systemMediaHandler.updateSystemMetadata(
        songTitle: title,
        artistName: artist,
        artworkUri: artworkUri,
        currentPosition: position,
        totalDuration: duration,
        isPlaying: isPlaying,
        currentLyricLine: currentLyric,
      );
    }
  }

  /// Resets state trackers when switching playlists or stopping playback completely.
  static void reset() {
    _lastLyricLine = null;
    _lastSongId = null;
    _lastPlayState = null;
  }
}
