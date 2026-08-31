import 'dart:collection';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:path/path.dart' as p;

import '../../utils/data_structures/group.dart';
import '../../utils/data_structures/track_metadata_item.dart';
import '../../utils/storage/database/interface.dart';

class GroupManager {
  final IDatabaseStorage db;
  final int maxCacheSize;

  /// Public flag tracking whether any updates, imports, or modifications have occurred.
  bool hasUpdated = false;

  final LinkedHashMap<String, GroupedTrackMetadataItem> lruCache =
  LinkedHashMap<String, GroupedTrackMetadataItem>();

  GroupManager({required this.db, this.maxCacheSize = 300});

  Future<List<GroupNode>> loadTwoLevelHierarchy() async {
    debugPrint('[GroupManager] Loading two-level group hierarchy...');
    final Stopwatch stopwatch = Stopwatch()..start();

    final parentEntities = await db.fetchSubGroups(parentId: null);
    final List<GroupNode> nodes = [];

    for (final parent in parentEntities) {
      final childEntities = await db.fetchSubGroups(parentId: parent.id);
      final List<GroupNode> childrenNodes = [];

      for (final child in childEntities) {
        final count = await db.fetchGroupTrackCount(child.id);
        childrenNodes.add(GroupNode(entity: child, totalTracks: count));
      }

      final parentTrackCount = await db.fetchGroupTrackCount(parent.id);
      nodes.add(GroupNode(
        entity: parent,
        subGroups: childrenNodes,
        totalTracks: parentTrackCount,
      ));
    }

    stopwatch.stop();
    debugPrint(
      '[GroupManager] Loaded ${nodes.length} parent nodes in ${stopwatch.elapsedMilliseconds}ms.',
    );
    return nodes;
  }

  /// Recursively loads the entire nested group tree hierarchy starting from root (parentId = 0 or null).
  Future<List<GroupNode>> loadGroupTree({int? parentId}) async {
    final targetParentId = parentId ?? 0;
    final entities = await db.fetchSubGroups(parentId: targetParentId);
    final List<GroupNode> nodes = [];

    for (final entity in entities) {
      // Recursively fetch sub-groups for current node
      final subNodes = await loadGroupTree(parentId: entity.id);
      final trackCount = await db.fetchGroupTrackCount(entity.id);

      nodes.add(GroupNode(
        entity: entity,
        subGroups: subNodes,
        totalTracks: trackCount,
      ));
    }

    return nodes;
  }

  Future<int> createGroup(String name, {int? parentId}) async {
    debugPrint('[GroupManager] Creating group "$name" with parentId: $parentId');
    final id = await db.insertGroup(name, parentId: parentId);
    hasUpdated = true;
    debugPrint('[GroupManager] Group "$name" created successfully with ID: $id');
    return id;
  }

  Future<void> renameGroup(int groupId, String newName) async {
    debugPrint('[GroupManager] Renaming group $groupId to "$newName"');
    await db.renameGroup(groupId, newName);
    hasUpdated = true;
    debugPrint('[GroupManager] Group $groupId renamed successfully.');
  }

  Future<void> assignTracksToGroup(List<String> filePaths, int groupId) async {
    debugPrint(
      '[GroupManager] Assigning ${filePaths.length} tracks to group $groupId',
    );
    await db.assignTracksToGroup(filePaths, groupId);
    hasUpdated = true;
    debugPrint('[GroupManager] Assigned tracks to group $groupId successfully.');
  }

  Future<void> removeTrackFromGroup(String filePath) async {
    debugPrint('[GroupManager] Removing track "$filePath" from its group');
    await db.removeTrackFromGroup(filePath);
    hasUpdated = true;
    debugPrint('[GroupManager] Removed track "$filePath" successfully.');
  }

  Future<void> deleteGroup(int groupId) async {
    debugPrint('[GroupManager] Deleting group ID $groupId');
    await db.deleteGroup(groupId);
    hasUpdated = true;
    debugPrint('[GroupManager] Group ID $groupId deleted successfully.');
  }

  /// Directly fetch group track window without managing window cursor
  Future<List<GroupedTrackMetadataItem>> fetchGroupTracksWindow(
      int groupId, {
        required int offset,
        required int limit,
      }) async {
    debugPrint(
      '[GroupManager] Direct fetch window for groupId: $groupId (offset: $offset, limit: $limit)',
    );
    final items =
    await db.fetchGroupTracksWindow(groupId, offset: offset, limit: limit);
    debugPrint(
      '[GroupManager] Fetched ${items.length} items for groupId: $groupId',
    );
    return items;
  }

  Future<List<GroupedTrackMetadataItem>> updateGroupWindow({
    required GroupWindowCursor cursor,
    required int visibleStartIndex,
    required int visibleEndIndex,
    int buffer = 10,
  }) async {
    debugPrint(
      '[GroupManager] Updating group window for groupId: ${cursor.groupId} '
          '(startIndex: $visibleStartIndex, endIndex: $visibleEndIndex)',
    );

    final totalCount = await db.fetchGroupTrackCount(cursor.groupId);
    debugPrint(
      '[GroupManager] Total track count for group ${cursor.groupId}: $totalCount',
    );

    if (totalCount == 0) {
      debugPrint(
        '[GroupManager] Group ${cursor.groupId} is empty, clearing cache cursor.',
      );
      cursor.cachedWindowItems.clear();
      return [];
    }

    final newL = (visibleStartIndex - buffer).clamp(0, totalCount - 1);
    final newR = (visibleEndIndex + buffer).clamp(0, totalCount - 1);

    if (newL == cursor.windowL &&
        newR == cursor.windowR &&
        cursor.cachedWindowItems.isNotEmpty) {
      debugPrint(
        '[GroupManager] Window unchanged [$newL..$newR]. Returning cached window items (${cursor.cachedWindowItems.length}).',
      );
      return cursor.cachedWindowItems;
    }

    cursor.windowL = newL;
    cursor.windowR = newR;
    final limit = (newR - newL) + 1;

    debugPrint(
      '[GroupManager] Fetching new window [$newL..$newR] (limit: $limit) from DB...',
    );
    final fetchedItems = await db.fetchGroupTracksWindow(
      cursor.groupId,
      offset: newL,
      limit: limit,
    );

    for (final item in fetchedItems) {
      if (lruCache.length >= maxCacheSize) {
        final evictedKey = lruCache.keys.first;
        lruCache.remove(evictedKey);
        debugPrint('[GroupManager] LRU Cache full. Evicted key: $evictedKey');
      }
      lruCache[item.filePath] = item;
    }

    cursor.cachedWindowItems = fetchedItems;
    debugPrint(
      '[GroupManager] Updated window for group ${cursor.groupId}. Cached ${fetchedItems.length} items. Total LRU size: ${lruCache.length}',
    );
    return fetchedItems;
  }

  Future<int> importFolderTwoLevel({
    required String parentGroupName,
    required String rootFolderPath,
    List<String> validExtensions = const [
      '.mp3',
      '.flac',
      '.wav',
      '.m4a',
      '.aac',
      '.ogg',
    ],
  }) async {
    debugPrint(
      '[GroupManager] Starting folder import from: "$rootFolderPath" under parent group "$parentGroupName"',
    );
    final Stopwatch stopwatch = Stopwatch()..start();

    final rootDir = Directory(rootFolderPath);
    if (!await rootDir.exists()) {
      debugPrint(
        '[GroupManager] Import failed: Directory "$rootFolderPath" does not exist.',
      );
      return 0;
    }

    final parentGroupId =
    await db.insertGroup(parentGroupName, parentId: null);
    hasUpdated = true;
    debugPrint(
      '[GroupManager] Created parent group "$parentGroupName" with ID: $parentGroupId',
    );

    final Map<String, int> subGroupIds = {};
    final Map<int, List<GroupedTrackMetadataItem>> pendingBatches = {};
    int totalFilesDiscovered = 0;

    await for (final entity
    in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (!validExtensions.contains(ext)) continue;

        totalFilesDiscovered++;
        final relativeFolder =
        p.relative(p.dirname(entity.path), from: rootFolderPath);
        int targetGroupId = parentGroupId;

        if (relativeFolder != '.') {
          final subName = p.split(relativeFolder).first;
          if (!subGroupIds.containsKey(subName)) {
            final childId =
            await db.insertGroup(subName, parentId: parentGroupId);
            subGroupIds[subName] = childId;
            debugPrint(
              '[GroupManager] Created sub-group "$subName" with ID: $childId',
            );
          }
          targetGroupId = subGroupIds[subName]!;
        }

        final meta = await TrackMetadataItem.fromPath(entity.path);
        final item = GroupedTrackMetadataItem.fromMetadata(
          id: 0,
          groupId: targetGroupId,
          metadata: meta,
        );

        pendingBatches.putIfAbsent(targetGroupId, () => []).add(item);
      }
    }

    debugPrint(
      '[GroupManager] Discovered $totalFilesDiscovered matching audio files across ${pendingBatches.keys.length} groups.',
    );

    for (final entry in pendingBatches.entries) {
      debugPrint(
        '[GroupManager] Saving batch of ${entry.value.length} tracks to group ID: ${entry.key}',
      );
      await db.saveGroupTracksBatch(entry.key, entry.value);
    }

    stopwatch.stop();
    hasUpdated = true;
    debugPrint(
      '[GroupManager] Folder import completed successfully in ${stopwatch.elapsedMilliseconds}ms.',
    );
    return parentGroupId;
  }

  /// Moves an existing track to a target group (or updates its group assignment in DB).
  Future<void> moveTrackToGroup(String filePath, int? targetGroupId) async {
    debugPrint('[GroupManager] Moving track "$filePath" to groupId: $targetGroupId');

    if (targetGroupId == null || targetGroupId == 0) {
      await db.removeTrackFromGroup(filePath);
    } else {
      await db.assignTracksToGroup([filePath], targetGroupId);
    }

    // Evict modified track from LRU cache so the new groupId reloads on demand
    lruCache.remove(filePath);
    hasUpdated = true;
    debugPrint('[GroupManager] Successfully moved "$filePath" and invalidated cache entry.');
  }

  /// Retrieves all tracks associated with a specific group ID.
  Future<List<GroupedTrackMetadataItem>> getGroupTracks(int groupId) async {
    debugPrint('[GroupManager] Fetching all tracks for groupId: $groupId');
    final tracks = await db.fetchGroupTracksWindow(groupId, offset: 0, limit: 10000);
    return tracks;
  }

  /// Moves a group (and its subtree) under a new parent group (or root if targetParentId is null).
  Future<void> moveGroup(int groupId, int? targetParentId) async {
    debugPrint('[GroupManager] Moving group $groupId to new parent: $targetParentId');
    await db.updateGroupParent(groupId, targetParentId);
    hasUpdated = true;
    debugPrint('[GroupManager] Group $groupId moved successfully.');
  }

  /// Removes a single track from a specific group.
  Future<void> deleteTrackFromGroup(String filePath, int groupId) async {
    debugPrint('[GroupManager] Deleting track "$filePath" from groupId: $groupId');
    await db.removeTrackFromGroup(filePath);
    lruCache.remove(filePath);
    hasUpdated = true;
    debugPrint('[GroupManager] Track "$filePath" removed from group $groupId.');
  }

  /// Removes a track completely across all group assignments.
  Future<void> deleteTrackFromAllGroups(String filePath) async {
    debugPrint('[GroupManager] Removing track "$filePath" from all groups.');
    await db.removeTrackFromGroup(filePath);
    lruCache.remove(filePath);
    hasUpdated = true;
  }

  /// Deletes a group entity and purges all nested/associated tracks directly.
  Future<void> deleteGroupAndCascadeTracks(int groupId) async {
    debugPrint('[GroupManager] Cascade deleting group ID: $groupId');

    // Fetch subgroups to cascade delete child groups recursively if needed
    final subGroups = await db.fetchSubGroups(parentId: groupId);
    for (final sub in subGroups) {
      await deleteGroupAndCascadeTracks(sub.id);
    }

    // Remove track entries tied to this group and delete the group record
    await db.deleteGroupTracksByGroupId(groupId);
    await db.deleteGroup(groupId);

    // Evict items from LRU cache
    lruCache.removeWhere((key, value) => value.groupId == groupId);
    hasUpdated = true;
    debugPrint('[GroupManager] Successfully deleted group ID: $groupId and its dependencies.');
  }

  /// Recursively scans a root folder and creates a nested subgroup tree mirroring
  /// the directory layout, importing matching audio tracks into their respective groups.
  Future<int> importFolderWithSubgroups({
    required String parentGroupName,
    required String rootFolderPath,
    int? parentId,
    List<String> validExtensions = const [
      '.mp3',
      '.flac',
      '.wav',
      '.m4a',
      '.aac',
      '.ogg',
    ],
    // Added progress callback: receives a descriptive status string and total tracks discovered so far
    void Function(String statusMessage, int tracksProcessed)? onProgress,
  }) async {
    debugPrint(
      '[GroupManager] Starting recursive folder import from: "$rootFolderPath" under parent group "$parentGroupName"',
    );
    final Stopwatch stopwatch = Stopwatch()..start();

    final rootDir = Directory(rootFolderPath);
    if (!await rootDir.exists()) {
      debugPrint(
        '[GroupManager] Import failed: Directory "$rootFolderPath" does not exist.',
      );
      return 0;
    }

    // 1. Create the main parent group for this import stream
    final int rootGroupId = await db.insertGroup(parentGroupName, parentId: parentId);
    hasUpdated = true;
    debugPrint(
      '[GroupManager] Created root group "$parentGroupName" with ID: $rootGroupId',
    );

    int totalTracksProcessed = 0;

    // Helper function to recursively traverse directories and mirror groups
    Future<void> processDirectory(Directory dir, int currentGameGroupId) async {
      final String currentDirName = p.basename(dir.path);
      onProgress?.call('Scanning folder: $currentDirName', totalTracksProcessed);

      final List<FileSystemEntity> entities = dir.listSync(followLinks: false);
      final List<GroupedTrackMetadataItem> currentFolderTracks = [];

      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (!validExtensions.contains(ext)) continue;

          // Parse metadata and bundle for batch insertion into the current group
          final meta = await TrackMetadataItem.fromPath(entity.path);
          final item = GroupedTrackMetadataItem.fromMetadata(
            id: 0,
            groupId: currentGameGroupId,
            metadata: meta,
          );
          currentFolderTracks.add(item);
          totalTracksProcessed++;
        }
      }

      // Save files found directly inside this specific folder level
      if (currentFolderTracks.isNotEmpty) {
        debugPrint(
          '[GroupManager] Saving batch of ${currentFolderTracks.length} tracks to group ID: $currentGameGroupId',
        );
        onProgress?.call('Saving tracks in "$currentDirName" (${currentFolderTracks.length})...', totalTracksProcessed);
        await db.saveGroupTracksBatch(currentGameGroupId, currentFolderTracks);
        hasUpdated = true;
      }

      // Recursively process subdirectories
      for (final entity in entities) {
        if (entity is Directory) {
          final subFolderName = p.basename(entity.path);
          debugPrint('[GroupManager] Creating subgroup "$subFolderName" under parent ID: $currentGameGroupId');

          onProgress?.call('Creating subgroup: $subFolderName', totalTracksProcessed);
          final subGroupId = await db.insertGroup(subFolderName, parentId: currentGameGroupId);
          hasUpdated = true;
          await processDirectory(entity, subGroupId);
        }
      }
    }

    // Kick off recursive processing from the root folder
    await processDirectory(rootDir, rootGroupId);

    stopwatch.stop();
    hasUpdated = true;
    debugPrint(
      '[GroupManager] Recursive folder import completed successfully in ${stopwatch.elapsedMilliseconds}ms.',
    );
    return rootGroupId;
  }
}
