import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';

class SystemMediaHandler extends BaseAudioHandler with SeekHandler {
  // Callbacks wired to your internal player engine
  VoidCallback? onPlayCallback;
  VoidCallback? onPauseCallback;
  VoidCallback? onSkipNextCallback;
  VoidCallback? onSkipPreviousCallback;
  ValueChanged<Duration>? onSeekCallback;

  SystemMediaHandler() {
    // Declare supported remote controls
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: AudioProcessingState.ready,
      playing: false,
    ));
  }

  /// Updates Lockscreen / Control Center display dynamically based on lyric state
  void updateSystemMetadata({
    required String songTitle,
    required String artistName,
    required Uri? artworkUri,
    required Duration currentPosition,
    required Duration totalDuration,
    required bool isPlaying,
    String? currentLyricLine,
  }) {
    final bool hasLyric = currentLyricLine != null && currentLyricLine.trim().isNotEmpty;

    final String displayTitle = hasLyric ? currentLyricLine : songTitle;
    final String displayArtist = hasLyric ? '$songTitle - $artistName' : artistName;

    // 1 & 2 & 3: Dynamic Metadata & Cover Art Mapping
    mediaItem.add(MediaItem(
      id: songTitle,
      title: displayTitle,
      artist: displayArtist,
      artUri: artworkUri,
      duration: totalDuration,
    ));

    // Update real-time playback state and seek position
    playbackState.add(playbackState.value.copyWith(
      playing: isPlaying,
      updatePosition: currentPosition,
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
    ));
  }

  // 4: System Command Triggers (Lock screen / Control Center / System Tray)
  @override
  Future<void> play() async => onPlayCallback?.call();

  @override
  Future<void> pause() async => onPauseCallback?.call();

  @override
  Future<void> skipToNext() async => onSkipNextCallback?.call();

  @override
  Future<void> skipToPrevious() async => onSkipPreviousCallback?.call();

  @override
  Future<void> seek(Duration position) async => onSeekCallback?.call(position);
}