import 'package:yl_music_player/controllers/audio_player_controller.dart';
import 'package:yl_music_player/utils/playlist_manager.dart';

mixin TrackStepperMixin {
  PlaylistManager get playlistManager;
  AudioPlayerController get audioController;

  void nextSong() {
    final nextItem = playlistManager.nextItem();
    if (nextItem == null) {
      audioController.loadEmpty();
    } else {
      audioController.loadTrack(nextItem.filePath);
    }
  }

  void prevSong() {
    final prevItem = playlistManager.prevItem();
    if (prevItem == null) {
      audioController.loadEmpty();
    } else {
      audioController.loadTrack(prevItem.filePath);
    }
  }

  void playCompleted() async {
    if (audioController.loopType == LoopType.loop) {
      nextSong();
    } else {
      final current = await playlistManager.getCurrentMetadata();
      if (current == null) {
        audioController.loadEmpty();
      } else {
        audioController.loadTrack(current.filePath);
      }
    }
  }
}