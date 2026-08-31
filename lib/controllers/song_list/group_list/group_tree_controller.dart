import 'dart:async';
import 'package:yl_music_player/utils/data_structures/group.dart';
import '../../../../../main.dart';

class GroupTreeController {
  List<GroupNode> nodes = [];
  final Set<int> expandedGroupIds = {};
  final Map<int, List<GroupedTrackMetadataItem>> groupTracks = {};
  final List<GroupNode?> navigateHistory = [];

  final Map<int, GroupNode> nodeCache = {};
  final Map<int, List<GroupNode>> breadcrumbCache = {};

  int? currentNavigationGroupId;
  final List<GroupNode> navigationBreadcrumb = [];

  String searchQuery = '';

  void init(List<GroupNode> rootNodes) {
    nodes = List.from(rootNodes);
    rebuildCache(nodes);
  }

  void rebuildCache(List<GroupNode> nodesList) {
    for (final node in nodesList) {
      nodeCache[node.entity.id] = node;
      rebuildCache(node.subGroups);
    }
  }

  void resetCache() {
    nodeCache.clear();
    breadcrumbCache.clear();
  }

  Future<void> loadRootTracks() async {
    groupTracks[0] = await groupManager.getGroupTracks(0);
  }

  Future<void> loadTracksForGroup(int groupId) async {
    if (!groupTracks.containsKey(groupId)) {
      groupTracks[groupId] = await groupManager.getGroupTracks(groupId);
    }
  }

  Set<int> getDescendantIds(GroupNode node) {
    final Set<int> ids = {node.entity.id};
    for (final sub in node.subGroups) {
      ids.addAll(getDescendantIds(sub));
    }
    return ids;
  }

  bool updateNodeInTree(List<GroupNode> list, int id, GroupNode Function(GroupNode) update) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].entity.id == id) {
        list[i] = update(list[i]);
        nodeCache[id] = list[i];
        return true;
      }
      if (updateNodeInTree(list[i].subGroups, id, update)) return true;
    }
    return false;
  }

  GroupNode? removeNodeFromTree(List<GroupNode> list, int id) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].entity.id == id) {
        nodeCache.remove(id);
        return list.removeAt(i);
      }
      final removed = removeNodeFromTree(list[i].subGroups, id);
      if (removed != null) return removed;
    }
    return null;
  }

  bool insertNodeInTree(List<GroupNode> list, int parentId, GroupNode node) {
    if (parentId == -1 || parentId == 0) {
      list.add(node);
      nodeCache[node.entity.id] = node;
      rebuildCache(node.subGroups);
      return true;
    }
    for (final item in list) {
      if (item.entity.id == parentId) {
        item.subGroups.add(node);
        nodeCache[node.entity.id] = node;
        rebuildCache(node.subGroups);
        return true;
      }
      if (insertNodeInTree(item.subGroups, parentId, node)) return true;
    }
    return false;
  }

  GroupNode? findNodeById(int id) => nodeCache[id];

  List<GroupNode> buildBreadcrumbTrail(int targetId) {
    if (breadcrumbCache.containsKey(targetId)) {
      return breadcrumbCache[targetId]!;
    }

    List<GroupNode> helper(int id, List<GroupNode> nodesList) {
      for (final node in nodesList) {
        if (node.entity.id == id) return [node];
        final subTrail = helper(id, node.subGroups);
        if (subTrail.isNotEmpty) return [node, ...subTrail];
      }
      return [];
    }

    final trail = helper(targetId, nodes);
    breadcrumbCache[targetId] = trail;
    return trail;
  }

  bool nodeOrChildrenMatch(GroupNode node, String query) {
    if (query.isEmpty) return true;
    final queryLower = query.toLowerCase();

    if (node.entity.name.toLowerCase().contains(queryLower)) return true;

    final tracks = groupTracks[node.entity.id] ?? [];
    if (tracks.any((t) => t.title.toLowerCase().contains(queryLower) || t.filePath.toLowerCase().contains(queryLower))) {
      return true;
    }

    return node.subGroups.any((sub) => nodeOrChildrenMatch(sub, queryLower));
  }

  List<GroupNode> filterNodes(List<GroupNode> nodesList, String query) {
    if (query.isEmpty) return nodesList;
    return nodesList.where((node) => nodeOrChildrenMatch(node, query)).toList();
  }
}