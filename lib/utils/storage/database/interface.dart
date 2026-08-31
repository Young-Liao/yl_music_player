import '../../data_structures/group.dart';
import '../../data_structures/track_metadata_item.dart';

abstract class IDatabaseStorage {
  Future<void> init();
  Future<void> close();

  // --- Current Active Queue Operations ---
  Future<List<String>> loadPlaylist();
  Future<void> savePlaylist(List<String> paths);

  // --- File List Library Operations ---
  Future<List<TrackMetadataItem>> loadFileList();
  Future<void> saveFileList(List<TrackMetadataItem> items);

  // --- Metadata Cache Operations ---
  Future<void> saveCachedMetadata(TrackMetadataItem metadata);
  Future<Map<String, TrackMetadataItem>> loadAllCachedMetadata();

  // --- Relational Group Operations (0-Based Hierarchy) ---
  Future<int> insertGroup(String name, {int? parentId});
  Future<List<GroupEntity>> fetchSubGroups({int? parentId});
  Future<int> fetchGroupTrackCount(int groupId);
  Future<List<GroupedTrackMetadataItem>> fetchGroupTracksWindow(
      int groupId, {
        required int offset,
        required int limit,
      });
  Future<void> saveGroupTracksBatch(
      int groupId,
      List<GroupedTrackMetadataItem> items,
      );
  Future<void> deleteGroup(int groupId);
  Future<void> renameGroup(int groupId, String newName);
  Future<void> assignTracksToGroup(List<String> filePaths, int? groupId);
  Future<void> removeTrackFromGroup(String filePath);

  Future<void> updateGroupParent(int groupId, int? parentId);
  Future<void> deleteGroupTracksByGroupId(int groupId);
}
