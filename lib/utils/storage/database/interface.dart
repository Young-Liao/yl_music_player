import '../../data_structures/track_metadata_item.dart';

/// Contract interface for handling local relational persistence.
abstract class IDatabaseStorage {
  Future<void> init();

  // Playlist Persistence
  Future<List<String>> loadPlaylist();
  Future<void> savePlaylist(List<String> paths);

  // Cached Metadata Persistence (Speeds up app startup cold launches)
  Future<void> saveCachedMetadata(TrackMetadataItem metadata);
  Future<Map<String, TrackMetadataItem>> loadAllCachedMetadata();

  Future<void> close();
}