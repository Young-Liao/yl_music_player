import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/controllers/lyrics_handler.dart';
import 'package:yl_music_player/controllers/playlist_manager.dart';

import 'data_structures/track_metadata_item.dart';

mixin TrackStepperMixin {
  PlaylistManager get playlistManager;
  AudioPlayerController get audioController;
  LyricsHandler get lyricsHandler;

  Future<void> loadSong(TrackMetadataItem? metadata) async {
    lyricsHandler.loadFromFile(metadata?.filePath);
    if (metadata == null) {
      audioController.loadEmpty();
    } else {
      await audioController.loadTrack(metadata.filePath);
    }
  }

  void nextSong() async {
    final oldState = audioController.isPlaying;
    final nextItem = playlistManager.nextItem();
    await loadSong(nextItem);
    await audioController.setPlaying(oldState);
    audioController.seek(Duration.zero);
  }

  void prevSong() async {
    final oldState = audioController.isPlaying;
    final prevItem = playlistManager.prevItem();
    await loadSong(prevItem);
    await audioController.setPlaying(oldState);
    audioController.seek(Duration.zero);
  }

  void playCompleted() async {
    if (audioController.loopType == LoopType.loop) {
      nextSong();
    } else {
      final current = await playlistManager.getCurrentMetadata();
      loadSong(current);
    }
  }
}