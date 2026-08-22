import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/utils/lyrics_handler.dart';
import 'package:yl_music_player/utils/playlist_manager.dart';

mixin TrackStepperMixin {
  PlaylistManager get playlistManager;
  AudioPlayerController get audioController;
  LyricsHandler get lyricsHandler;

  void loadSong(TrackMetadataItem? metadata) {
    lyricsHandler.loadFromFile(metadata?.filePath);
    if (metadata == null) {
      audioController.loadEmpty();
    } else {
      audioController.loadTrack(metadata.filePath);
    }
  }

  void nextSong() {
    final nextItem = playlistManager.nextItem();
    loadSong(nextItem);
  }

  void prevSong() {
    final prevItem = playlistManager.prevItem();
    loadSong(prevItem);
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