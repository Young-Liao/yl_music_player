import 'dart:async';

import 'package:flutter/material.dart';

import 'package:yl_music_player/components/file_manager/views/group/widgets/group_node_tile.dart';
import 'package:yl_music_player/components/file_manager/views/group/widgets/nested_group_picker_dialog.dart';
import 'package:yl_music_player/components/file_manager/views/group/widgets/track_tile.dart';

import '../../../../../main.dart';
import '../../../../../themes/app_theme_interface.dart';
import '../../../../../themes/theme_provider.dart';
import '../../../../../utils/data_structures/group.dart';

class GroupListView extends StatefulWidget {
  final List<GroupNode> rootNodes;
  final ScrollController scrollController;
  final ValueChanged<String> onPlayTrack;
  final ValueChanged<String> onMoveToNext;

  final bool isSelectionMode;
  final Set<GroupNode> selectedGroups;
  final Set<String> selectedTrackPaths;
  final ValueChanged<GroupNode> onToggleGroupSelect;
  final ValueChanged<String> onToggleTrackSelect;

  final bool areAllSelected;
  final VoidCallback onToggleSelectAll;

  final String? activeTrackPath;

  const GroupListView({
    super.key,
    required this.rootNodes,
    required this.scrollController,
    required this.onPlayTrack,
    required this.onMoveToNext,
    required this.isSelectionMode,
    required this.selectedGroups,
    required this.selectedTrackPaths,
    required this.onToggleGroupSelect,
    required this.onToggleTrackSelect,
    required this.areAllSelected,
    required this.onToggleSelectAll,
    this.activeTrackPath,
  });

  @override
  State<GroupListView> createState() => GroupListViewState();
}

class GroupListViewState extends State<GroupListView> {
  final Set<int> _expandedGroupIds = {};

  final Map<int, List<GroupedTrackMetadataItem>> _groupTracks = {};

  late List<GroupNode> _nodes;
  final List<GroupNode?> _navigateHistory = [];

  // O(1) group lookup.
  final Map<int, GroupNode> _nodeCache = {};

  // Cached breadcrumb paths.
  final Map<int, List<GroupNode>> _breadcrumbCache = {};

  // Navigation state.
  int? _currentNavigationGroupId;
  final List<GroupNode> _navigationBreadcrumb = [];

  // Search state.
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Horizontal table scrolling.
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _nodes = List.from(widget.rootNodes);
    _rebuildCache(_nodes);
    _loadRootTracks();
  }

  void _rebuildCache(List<GroupNode> nodes, [GroupNode? parent]) {
    for (final node in nodes) {
      _nodeCache[node.entity.id] = node;
      _rebuildCache(node.subGroups, node);
    }
  }

  Future<void> _loadRootTracks() async {
    final rootTracks = await groupManager.getGroupTracks(0);

    if (!mounted) return;

    setState(() {
      _groupTracks[0] = rootTracks;
    });
  }

  @override
  void didUpdateWidget(covariant GroupListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rootNodes != oldWidget.rootNodes) {
      _nodes = List.from(widget.rootNodes);

      _nodeCache.clear();
      _breadcrumbCache.clear();

      _rebuildCache(_nodes);
    }

    if (groupManager.hasUpdated) {
      // Reload the entire group tree hierarchy from the database to capture imported groups/folders
      groupManager.loadGroupTree().then((updatedNodes) {
        if (!mounted) return;
        setState(() {
          _nodes = updatedNodes;
          _nodeCache.clear();
          _breadcrumbCache.clear();
          _rebuildCache(_nodes);
        });
      });

      groupManager.hasUpdated = false;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _horizontalScrollController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Group tree helpers
  // ---------------------------------------------------------------------------

  Set<int> _getDescendantIds(GroupNode node) {
    final Set<int> ids = {node.entity.id};

    for (final sub in node.subGroups) {
      ids.addAll(_getDescendantIds(sub));
    }

    return ids;
  }

  bool _updateNodeInTree(
    List<GroupNode> list,
    int id,
    GroupNode Function(GroupNode) update,
  ) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].entity.id == id) {
        list[i] = update(list[i]);
        _nodeCache[id] = list[i];
        return true;
      }

      if (_updateNodeInTree(list[i].subGroups, id, update)) {
        return true;
      }
    }

    return false;
  }

  GroupNode? _removeNodeFromTree(List<GroupNode> list, int id) {
    for (int i = 0; i < list.length; i++) {
      if (list[i].entity.id == id) {
        _nodeCache.remove(id);
        return list.removeAt(i);
      }

      final removed = _removeNodeFromTree(list[i].subGroups, id);

      if (removed != null) {
        return removed;
      }
    }

    return null;
  }

  bool _insertNodeInTree(List<GroupNode> list, int parentId, GroupNode node) {
    if (parentId == -1 || parentId == 0) {
      list.add(node);

      _nodeCache[node.entity.id] = node;
      _rebuildCache(node.subGroups);

      return true;
    }

    for (final item in list) {
      if (item.entity.id == parentId) {
        item.subGroups.add(node);

        _nodeCache[node.entity.id] = node;
        _rebuildCache(node.subGroups);

        return true;
      }

      if (_insertNodeInTree(item.subGroups, parentId, node)) {
        return true;
      }
    }

    return false;
  }

  GroupNode? _findNodeById(int id) {
    return _nodeCache[id];
  }

  List<GroupNode> _buildBreadcrumbTrail(int targetId) {
    if (_breadcrumbCache.containsKey(targetId)) {
      return _breadcrumbCache[targetId]!;
    }

    List<GroupNode> helper(int id, List<GroupNode> nodes) {
      for (final node in nodes) {
        if (node.entity.id == id) {
          return [node];
        }

        final subTrail = helper(id, node.subGroups);

        if (subTrail.isNotEmpty) {
          return [node, ...subTrail];
        }
      }

      return [];
    }

    final trail = helper(targetId, _nodes);

    _breadcrumbCache[targetId] = trail;

    return trail;
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToGroup(GroupNode? node) async {
    setState(() {
      if (node == null) {
        _currentNavigationGroupId = null;
        _navigationBreadcrumb.clear();
      } else {
        _currentNavigationGroupId = node.entity.id;

        _navigationBreadcrumb.clear();
        _navigationBreadcrumb.addAll(_buildBreadcrumbTrail(node.entity.id));
      }
    });

    _navigateHistory.add(node);

    final targetId = node?.entity.id ?? 0;

    if (!_groupTracks.containsKey(targetId)) {
      final tracks = await groupManager.getGroupTracks(targetId);

      if (!mounted) return;

      setState(() {
        _groupTracks[targetId] = tracks;
      });
    }
  }

  void _toggleExpand(GroupNode node) async {
    final groupId = node.entity.id;

    final bool isExpanding = !_expandedGroupIds.contains(groupId);

    setState(() {
      if (isExpanding) {
        _expandedGroupIds.add(groupId);
      } else {
        _expandedGroupIds.remove(groupId);
      }
    });

    if (isExpanding) {
      final tracks = await groupManager.getGroupTracks(groupId);

      if (!mounted) return;

      setState(() {
        _groupTracks[groupId] = tracks;
        node.totalTracks = tracks.length;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Group operations
  // ---------------------------------------------------------------------------

  Future<void> _handleAddSubgroup(GroupNode parentNode) async {
    final textController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Subgroup to ${parentNode.entity.name}'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Group Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, textController.text.trim());
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      final newGroupId = await groupManager.createGroup(
        name,
        parentId: parentNode.entity.id,
      );

      final newNode = GroupNode(
        entity: GroupEntity(
          id: newGroupId,
          name: name,
          parentId: parentNode.entity.id,
        ),
        subGroups: [],
        totalTracks: 0,
      );

      setState(() {
        parentNode.subGroups.add(newNode);

        _nodeCache[newGroupId] = newNode;

        _breadcrumbCache.clear();

        _expandedGroupIds.add(parentNode.entity.id);
      });
    }
  }

  Future<void> _handleMoveGroup(GroupNode node) async {
    final targetGroup = await showDialog<GroupNode>(
      context: context,
      builder: (context) {
        return NestedGroupPickerDialog(
          rootNodes: _nodes,
          currentGroupId: node.entity.id,
        );
      },
    );

    if (targetGroup != null) {
      final newParentId = targetGroup.entity.id;

      await groupManager.moveGroup(
        node.entity.id,
        newParentId == 0 ? null : newParentId,
      );

      setState(() {
        final removed = _removeNodeFromTree(_nodes, node.entity.id);

        if (removed != null) {
          _insertNodeInTree(_nodes, newParentId, removed);

          _breadcrumbCache.clear();

          if (newParentId != 0) {
            _expandedGroupIds.add(newParentId);
          }
        }
      });
    }
  }

  Future<void> _handleRenameGroup(GroupNode node) async {
    final textController = TextEditingController(text: node.entity.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename Group'),
          content: TextField(controller: textController, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, textController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != node.entity.name) {
      await groupManager.renameGroup(node.entity.id, newName);

      setState(() {
        node.entity.name = newName;
        _breadcrumbCache.clear();
      });
    }
  }

  Future<void> _handleDeleteGroup(GroupNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${node.entity.name}?'),
          content: const Text(
            'This action removes the group and deletes stored tracks inside this group directly.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final idsToDelete = _getDescendantIds(node);

      await groupManager.deleteGroupAndCascadeTracks(node.entity.id);

      setState(() {
        _removeNodeFromTree(_nodes, node.entity.id);

        _breadcrumbCache.clear();

        for (final id in idsToDelete) {
          _expandedGroupIds.remove(id);
          _groupTracks.remove(id);
        }

        if (_currentNavigationGroupId != null &&
            idsToDelete.contains(_currentNavigationGroupId)) {
          _navigateToGroup(null);
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Track operations
  // ---------------------------------------------------------------------------

  Future<void> _handleMoveTrackToGroup(
    GroupedTrackMetadataItem track,
    int currentGroupId,
  ) async {
    final targetGroup = await showDialog<GroupNode>(
      context: context,
      builder: (context) {
        return NestedGroupPickerDialog(
          rootNodes: _nodes,
          currentGroupId: currentGroupId,
        );
      },
    );

    if (targetGroup != null) {
      final targetGroupId = targetGroup.entity.id;

      await groupManager.moveTrackToGroup(
        track.filePath,
        targetGroupId == 0 ? null : targetGroupId,
      );

      _refreshTrackCount(currentGroupId);
      _refreshTrackCount(targetGroupId);
    }
  }

  Future<void> _handleDeleteTrackInternal(
    GroupedTrackMetadataItem track,
    int groupId,
  ) async {
    await groupManager.deleteTrackFromGroup(track.filePath, groupId);

    setState(() {
      _groupTracks[groupId]?.removeWhere((t) => t.filePath == track.filePath);

      _updateNodeInTree(_nodes, groupId, (node) {
        node.totalTracks = node.totalTracks > 0 ? node.totalTracks - 1 : 0;

        return node;
      });
    });
  }

  Future<List<String>> extractAllSelectedTrackPaths() async {
    final List<String> paths = widget.selectedTrackPaths.toList();

    for (final group in widget.selectedGroups) {
      final groupTracks = await groupManager.getGroupTracks(group.entity.id);

      paths.addAll(groupTracks.map((t) => t.filePath));
    }

    return paths.toSet().toList();
  }

  Future<void> showBatchMoveDialog({VoidCallback? onCompleteSelection}) async {
    final selectedPaths = widget.selectedTrackPaths.toList();

    if (selectedPaths.isEmpty && widget.selectedGroups.isEmpty) {
      return;
    }

    final targetGroup = await showDialog<GroupNode>(
      context: context,
      builder: (context) {
        return NestedGroupPickerDialog(rootNodes: _nodes, currentGroupId: -1);
      },
    );

    if (targetGroup != null) {
      final targetGroupId = targetGroup.entity.id;

      if (selectedPaths.isNotEmpty) {
        await groupManager.assignTracksToGroup(selectedPaths, targetGroupId);
      }

      if (!mounted) return;

      setState(() {
        for (final entry in _groupTracks.entries) {
          entry.value.removeWhere((t) => selectedPaths.contains(t.filePath));
        }
      });

      await _refreshTrackCount(targetGroupId);

      onCompleteSelection?.call();
    }
  }

  Future<void> _refreshTrackCount(int groupId) async {
    final tracks = await groupManager.getGroupTracks(groupId);

    if (!mounted) return;

    setState(() {
      _groupTracks[groupId] = tracks;

      if (groupId != 0) {
        _updateNodeInTree(_nodes, groupId, (node) {
          node.totalTracks = tracks.length;
          return node;
        });
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  bool _nodeOrChildrenMatch(GroupNode node, String query) {
    if (query.isEmpty) return true;

    final queryLower = query.toLowerCase();

    // 1. Check if the current group node name matches
    if (node.entity.name.toLowerCase().contains(queryLower)) {
      return true;
    }

    // 2. Check if any loaded tracks in this group match
    final tracks = _groupTracks[node.entity.id] ?? [];
    if (tracks.any(
      (t) =>
          t.title.toLowerCase().contains(queryLower) ||
          t.filePath.toLowerCase().contains(queryLower),
    )) {
      return true;
    }

    // 3. Check if any subgroup recursively matches
    return node.subGroups.any((sub) => _nodeOrChildrenMatch(sub, queryLower));
  }

  List<GroupNode> _filterNodes(List<GroupNode> nodes, String query) {
    if (query.isEmpty) return nodes;

    List<GroupNode> filteredList = [];
    for (final node in nodes) {
      if (_nodeOrChildrenMatch(node, query)) {
        filteredList.add(node);
      }
    }
    return filteredList;
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  TextStyle _headerTextStyle(IAppTheme theme) {
    return TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      color: theme.textMuted,
      letterSpacing: 0.8,
    );
  }

  Widget _buildSearchBar() {
    final theme = CustomThemeProvider.of(context);

    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search sub-groups and tracks below current path...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();

                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: theme.cardBackgroundColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.textMuted.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: theme.textMuted.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: theme.primaryColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      onChanged: (value) {
        _debounceTimer?.cancel();

        _debounceTimer = Timer(const Duration(milliseconds: 150), () {
          if (!mounted) return;

          setState(() {
            _searchQuery = value.trim().toLowerCase();
          });
        });
      },
    );
  }

  Widget _buildNavigationBar() {
    final theme = CustomThemeProvider.of(context);

    final bool canGoBack =
        _currentNavigationGroupId != null && _currentNavigationGroupId != 0;

    return Row(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: theme.cardBackgroundColor,
            foregroundColor: theme.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: theme.textMuted.withValues(alpha: 0.3)),
            ),
          ),
          onPressed: canGoBack
              ? () {
                  if (_navigateHistory.isNotEmpty) {
                    _navigateHistory.removeLast();
                  }
                  final to = _navigateHistory.lastOrNull;
                  if (_navigateHistory.isNotEmpty) {
                    _navigateHistory.removeLast();
                  }
                  _navigateToGroup(to);

                  debugPrint("History: $_navigateHistory");
                }
              : null,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back'),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.cardBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.textMuted.withValues(alpha: 0.3)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(
                    Icons.home_outlined,
                    size: 14,
                    color: theme.textSecondary,
                  ),

                  const SizedBox(width: 4),

                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => _navigateToGroup(null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Text(
                        'Root',
                        style: TextStyle(
                          fontSize: 13,
                          color: _currentNavigationGroupId == null
                              ? theme.primaryColor
                              : theme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  for (int i = 0; i < _navigationBreadcrumb.length; i++) ...[
                    Text(
                      ' / ',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _navigateToGroup(_navigationBreadcrumb[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          _navigationBreadcrumb[i].entity.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: i == _navigationBreadcrumb.length - 1
                                ? theme.primaryColor
                                : theme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupNode(GroupNode node, int indentLevel) {
    final theme = CustomThemeProvider.of(context);

    final bool isSearching = _searchQuery.isNotEmpty;

    final bool isExpanded = isSearching
        ? _nodeOrChildrenMatch(node, _searchQuery)
        : _expandedGroupIds.contains(node.entity.id);

    final tracks = _groupTracks[node.entity.id] ?? [];

    return GroupNodeTile(
      key: ValueKey('group_${node.entity.id}'),
      group: node,
      indentLevel: indentLevel,
      isExpanded: isExpanded,
      isSelected: widget.selectedGroups.contains(node),
      isSelectionMode: widget.isSelectionMode,
      theme: theme,
      onToggleExpand: () => _toggleExpand(node),
      onNavigate: () => _navigateToGroup(node),
      onToggleSelect: widget.onToggleGroupSelect,
      onAddSubgroup: () => _handleAddSubgroup(node),
      onMoveGroup: () => _handleMoveGroup(node),
      onRename: () => _handleRenameGroup(node),
      onDelete: () => _handleDeleteGroup(node),
      buildChildGroup: (sub, level) => _buildGroupNode(sub, level),
      buildChildTrack: (track, groupId, level) =>
          _buildTrackNode(track, groupId, level),
      tracks: tracks,
    );
  }

  Widget _buildTrackNode(
    GroupedTrackMetadataItem track,
    int groupId,
    int level,
  ) {
    final theme = CustomThemeProvider.of(context);

    final bool isActive = widget.activeTrackPath == track.filePath;

    return TrackTile(
      key: ValueKey('track_${track.filePath}'),
      track: track,
      groupId: groupId,
      indentLevel: level,
      isSelected: widget.selectedTrackPaths.contains(track.filePath),
      isActive: isActive,
      isSelectionMode: widget.isSelectionMode,
      theme: theme,
      onPlayTrack: widget.onPlayTrack,
      onToggleTrackSelect: widget.onToggleTrackSelect,
      onMoveToNext: widget.onMoveToNext,
      onDeleteTrack: (path) => _handleDeleteTrackInternal(track, groupId),
      onMoveToGroup: (trackItem, currentGroupId) =>
          _handleMoveTrackToGroup(trackItem, currentGroupId),
    );
  }

  Widget _buildGroupsTable() {
    final theme = CustomThemeProvider.of(context);

    List<GroupNode> currentNodes;
    List<GroupedTrackMetadataItem> currentTracks = [];

    if (_currentNavigationGroupId == null || _currentNavigationGroupId == 0) {
      currentNodes = _nodes;
      currentTracks = _groupTracks[0] ?? [];
    } else {
      final activeParentNode = _findNodeById(_currentNavigationGroupId!);
      currentNodes = activeParentNode?.subGroups ?? [];
      currentTracks = _groupTracks[_currentNavigationGroupId!] ?? [];
    }

    // Apply corrected recursive search filter
    if (_searchQuery.isNotEmpty) {
      currentNodes = _filterNodes(currentNodes, _searchQuery);

      // If we are at a specific navigation group, check if any tracks match or if they belong to matching subtrees
      currentTracks = currentTracks
          .where(
            (t) =>
                t.title.toLowerCase().contains(_searchQuery) ||
                t.filePath.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }

    final totalItems = currentNodes.length + currentTracks.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------------
          // Title Row with Rightmost Add Button
          // -------------------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Music Groups Items',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                color: theme.primaryColor,
                tooltip: 'Add Group',
                onPressed: () async {
                  if (_currentNavigationGroupId == null ||
                      _currentNavigationGroupId == 0) {
                    // Creating a root-level group (or handle via root creator if supported,
                    // otherwise prompt for root group creation)
                    await _handleRootGroupCreation();
                  } else {
                    final parentNode = _findNodeById(
                      _currentNavigationGroupId!,
                    );
                    if (parentNode != null) {
                      await _handleAddSubgroup(parentNode);
                    }
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // -------------------------------------------------------------------
          // Table Layout
          // -------------------------------------------------------------------
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double minTableWidth = 550.0;
                final double tableWidth = constraints.maxWidth > minTableWidth
                    ? constraints.maxWidth
                    : minTableWidth;

                return Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 4.0,
                            ),
                            child: Row(
                              children: [
                                if (widget.isSelectionMode) ...[
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Checkbox(
                                      value: widget.areAllSelected,
                                      activeColor: theme.primaryColor,
                                      onChanged: (_) =>
                                          widget.onToggleSelectAll(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                Expanded(
                                  flex: 5,
                                  child: Text(
                                    'GROUP / TRACK TITLE',
                                    style: _headerTextStyle(theme),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'ALBUM',
                                    style: _headerTextStyle(theme),
                                  ),
                                ),
                                const SizedBox(width: 32),
                              ],
                            ),
                          ),

                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.outerBackgroundColor,
                          ),

                          const SizedBox(height: 8),

                          // Rows
                          Expanded(
                            child: ListView.builder(
                              controller: widget.scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: totalItems,
                              itemBuilder: (context, index) {
                                if (index < currentNodes.length) {
                                  return _buildGroupNode(
                                    currentNodes[index],
                                    0,
                                  );
                                }

                                final trackIndex = index - currentNodes.length;
                                final track = currentTracks[trackIndex];
                                final targetGroupId =
                                    _currentNavigationGroupId ?? 0;

                                return _buildTrackNode(track, targetGroupId, 0);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRootGroupCreation() async {
    final textController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Root Group'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Group Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, textController.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      final newGroupId = await groupManager.createGroup(name);
      final newNode = GroupNode(
        entity: GroupEntity(id: newGroupId, name: name, parentId: null),
        subGroups: [],
        totalTracks: 0,
      );

      setState(() {
        _nodes.add(newNode);
        _nodeCache[newGroupId] = newNode;
        _breadcrumbCache.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search MUST be first.
        _buildSearchBar(),

        const SizedBox(height: 10),

        // Back + breadcrumb MUST be below search.
        _buildNavigationBar(),

        const SizedBox(height: 16),

        // Everything below this point belongs to the
        // FileListView-style shadow card.
        Expanded(child: _buildGroupsTable()),
      ],
    );
  }
}
