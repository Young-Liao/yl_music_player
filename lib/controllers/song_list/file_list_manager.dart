import 'package:yl_music_player/controllers/song_list/song_list_managers.dart';

import '../../utils/data_structures/track_metadata_item.dart';

class FileListManager extends SongListManager {
  FileListManager({required super.db, super.maxCacheSize = 250});

  // Mock track metadata corresponding to the UI design
  final List<TrackMetadataItem> _mockTracks = [
    TrackMetadataItem(
      filePath: '/music/midnight_city.mp3',
      title: 'Midnight City',
      artist: 'M83',
      album: "Hurry Up, We're Dreaming",
      duration: const Duration(minutes: 4, seconds: 3),
    ),
    TrackMetadataItem(
      filePath: '/music/starboy.mp3',
      title: 'Starboy',
      artist: 'The Weeknd, Daft Punk',
      album: 'Starboy',
      duration: const Duration(minutes: 3, seconds: 50),
    ),
    TrackMetadataItem(
      filePath: '/music/get_lucky.mp3',
      title: 'Get Lucky',
      artist: 'Daft Punk ft. Pharrell Williams',
      album: 'Random Access Memories',
      duration: const Duration(minutes: 4, seconds: 8),
    ),
    TrackMetadataItem(
      filePath: '/music/resonance.mp3',
      title: 'Resonance',
      artist: 'HOME',
      album: 'Odyssey',
      duration: const Duration(minutes: 3, seconds: 32),
    ),
  ];

  @override
  int get length => _mockTracks.length;

  @override
  List<String> get songPaths => _mockTracks.map((e) => e.filePath).toList();

  @override
  TrackMetadataItem getCachedMetadataAtIndex(int index) {
    if (index < 0 || index >= _mockTracks.length) {
      return TrackMetadataItem.empty();
    }
    return _mockTracks[index];
  }
}