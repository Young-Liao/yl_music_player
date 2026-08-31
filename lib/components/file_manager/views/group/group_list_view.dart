import 'package:flutter/material.dart';

import 'package:yl_music_player/components/file_manager/views/group/widgets/group_list_navigation_bar.dart';
import 'package:yl_music_player/components/file_manager/views/group/widgets/group_list_search_bar.dart';
import 'package:yl_music_player/components/file_manager/views/group/widgets/group_node_tile.dart';
import 'package:yl_music_player/components/file_manager/views/group/widgets/nested_group_picker_dialog.dart';
import 'package:yl_music_player/components/file_manager/views/group/widgets/track_tile.dart';

import '../../../../../main.dart';
import '../../../../../themes/app_theme_interface.dart';
import '../../../../../themes/theme_provider.dart';
import '../../../../../utils/data_structures/group.dart';
import '../../../../controllers/song_list/group_list/group_tree_controller.dart';

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
  final GroupTreeController _treeCtrl = GroupTreeController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _treeCtrl.init(widget.rootNodes);
    _treeCtrl.loadRootTracks().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant GroupListView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rootNodes != oldWidget.rootNodes) {
      _treeCtrl.nodes = List.from(widget.rootNodes);
      _treeCtrl.resetCache();
      _treeCtrl.rebuildCache(_treeCtrl.nodes);
    }

    if (groupManager.hasUpdated) {
      groupManager.loadGroupTree().then((updatedNodes) {
        if (!mounted) return;
        setState(() {
          _treeCtrl.nodes = updatedNodes;
          _treeCtrl.resetCache();
          _treeCtrl.rebuildCache(_treeCtrl.nodes);
        });
      });
      groupManager.hasUpdated = false;
    }
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation & Operations
  // ---------------------------------------------------------------------------

  void _navigateToGroup(GroupNode? node) async {
    setState(() {
      if (node == null) {
        _treeCtrl.currentNavigationGroupId = null;
        _treeCtrl.navigationBreadcrumb.clear();
      } else {
        _treeCtrl.currentNavigationGroupId = node.entity.id;
        _treeCtrl.navigationBreadcrumb.clear();
        _treeCtrl.navigationBreadcrumb.addAll(_treeCtrl.buildBreadcrumbTrail(node.entity.id));
      }
    });

    _treeCtrl.navigateHistory.add(node);
    final targetId = node?.entity.id ?? 0;

    await _treeCtrl.loadTracksForGroup(targetId);
    if (mounted) setState(() {});
  }

  void _toggleExpand(GroupNode node) async {
    final groupId = node.entity.id;
    final bool isExpanding = !_treeCtrl.expandedGroupIds.contains(groupId);

    setState(() {
      if (isExpanding) {
        _treeCtrl.expandedGroupIds.add(groupId);
      } else {
        _treeCtrl.expandedGroupIds.remove(groupId);
      }
    });

    if (isExpanding) {
      final tracks = await groupManager.getGroupTracks(groupId);
      if (!mounted) return;
      setState(() {
        _treeCtrl.groupTracks[groupId] = tracks;
        node.totalTracks = tracks.length;
      });
    }
  }

  Future<void> _handleAddSubgroup(GroupNode parentNode) async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Subgroup to ${parentNode.entity.name}'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newGroupId = await groupManager.createGroup(name, parentId: parentNode.entity.id);
      final newNode = GroupNode(
        entity: GroupEntity(id: newGroupId, name: name, parentId: parentNode.entity.id),
        subGroups: [],
        totalTracks: 0,
      );

      setState(() {
        parentNode.subGroups.add(newNode);
        _treeCtrl.nodeCache[newGroupId] = newNode;
        _treeCtrl.breadcrumbCache.clear();
        _treeCtrl.expandedGroupIds.add(parentNode.entity.id);
      });
    }
  }

  Future<void> _handleMoveGroup(GroupNode node) async {
    final targetGroup = await showDialog<GroupNode>(
      context: context,
      builder: (context) => NestedGroupPickerDialog(rootNodes: _treeCtrl.nodes, currentGroupId: node.entity.id),
    );

    if (targetGroup != null) {
      final newParentId = targetGroup.entity.id;
      await groupManager.moveGroup(node.entity.id, newParentId == 0 ? null : newParentId);

      setState(() {
        final removed = _treeCtrl.removeNodeFromTree(_treeCtrl.nodes, node.entity.id);
        if (removed != null) {
          _treeCtrl.insertNodeInTree(_treeCtrl.nodes, newParentId, removed);
          _treeCtrl.breadcrumbCache.clear();
          if (newParentId != 0) _treeCtrl.expandedGroupIds.add(newParentId);
        }
      });
    }
  }

  Future<void> _handleRenameGroup(GroupNode node) async {
    final textController = TextEditingController(text: node.entity.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Group'),
        content: TextField(controller: textController, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != node.entity.name) {
      await groupManager.renameGroup(node.entity.id, newName);
      setState(() {
        node.entity.name = newName;
        _treeCtrl.breadcrumbCache.clear();
      });
    }
  }

  Future<void> _handleDeleteGroup(GroupNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${node.entity.name}?'),
        content: const Text('This action removes the group and deletes stored tracks inside this group directly.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final idsToDelete = _treeCtrl.getDescendantIds(node);
      await groupManager.deleteGroupAndCascadeTracks(node.entity.id);

      setState(() {
        _treeCtrl.removeNodeFromTree(_treeCtrl.nodes, node.entity.id);
        _treeCtrl.breadcrumbCache.clear();
        for (final id in idsToDelete) {
          _treeCtrl.expandedGroupIds.remove(id);
          _treeCtrl.groupTracks.remove(id);
        }
        if (_treeCtrl.currentNavigationGroupId != null && idsToDelete.contains(_treeCtrl.currentNavigationGroupId)) {
          _navigateToGroup(null);
        }
      });
    }
  }

  Future<void> _handleMoveTrackToGroup(GroupedTrackMetadataItem track, int currentGroupId) async {
    final targetGroup = await showDialog<GroupNode>(
      context: context,
      builder: (context) => NestedGroupPickerDialog(rootNodes: _treeCtrl.nodes, currentGroupId: currentGroupId),
    );

    if (targetGroup != null) {
      final targetGroupId = targetGroup.entity.id;
      await groupManager.moveTrackToGroup(track.filePath, targetGroupId == 0 ? null : targetGroupId);
      _refreshTrackCount(currentGroupId);
      _refreshTrackCount(targetGroupId);
    }
  }

  Future<void> _handleDeleteTrackInternal(GroupedTrackMetadataItem track, int groupId) async {
    await groupManager.deleteTrackFromGroup(track.filePath, groupId);
    setState(() {
      _treeCtrl.groupTracks[groupId]?.removeWhere((t) => t.filePath == track.filePath);
      _treeCtrl.updateNodeInTree(_treeCtrl.nodes, groupId, (node) {
        node.totalTracks = node.totalTracks > 0 ? node.totalTracks - 1 : 0;
        return node;
      });
    });
  }

  Future<void> _refreshTrackCount(int groupId) async {
    final tracks = await groupManager.getGroupTracks(groupId);
    if (!mounted) return;
    setState(() {
      _treeCtrl.groupTracks[groupId] = tracks;
      if (groupId != 0) {
        _treeCtrl.updateNodeInTree(_treeCtrl.nodes, groupId, (node) {
          node.totalTracks = tracks.length;
          return node;
        });
      }
    });
  }

  Future<void> _handleRootGroupCreation() async {
    final textController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Root Group'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Group Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, textController.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final newGroupId = await groupManager.createGroup(name);
      final newNode = GroupNode(
        entity: GroupEntity(id: newGroupId, name: name, parentId: null),
        subGroups: [],
        totalTracks: 0,
      );

      setState(() {
        _treeCtrl.nodes.add(newNode);
        _treeCtrl.nodeCache[newGroupId] = newNode;
        _treeCtrl.breadcrumbCache.clear();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Public APIs for parent widgets
  // ---------------------------------------------------------------------------

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
    if (selectedPaths.isEmpty && widget.selectedGroups.isEmpty) return;

    final targetGroup = await showDialog<GroupNode>(
      context: context,
      builder: (context) => NestedGroupPickerDialog(rootNodes: _treeCtrl.nodes, currentGroupId: -1),
    );

    if (targetGroup != null) {
      final targetGroupId = targetGroup.entity.id;
      if (selectedPaths.isNotEmpty) {
        await groupManager.assignTracksToGroup(selectedPaths, targetGroupId);
      }
      if (!mounted) return;

      setState(() {
        for (final entry in _treeCtrl.groupTracks.entries) {
          entry.value.removeWhere((t) => selectedPaths.contains(t.filePath));
        }
      });

      await _refreshTrackCount(targetGroupId);
      onCompleteSelection?.call();
    }
  }

  // ---------------------------------------------------------------------------
  // Builder methods
  // ---------------------------------------------------------------------------

  Widget _buildGroupNode(GroupNode node, int indentLevel) {
    final theme = CustomThemeProvider.of(context);
    final bool isSearching = _treeCtrl.searchQuery.isNotEmpty;
    final bool isExpanded = isSearching
        ? _treeCtrl.nodeOrChildrenMatch(node, _treeCtrl.searchQuery)
        : _treeCtrl.expandedGroupIds.contains(node.entity.id);

    final tracks = _treeCtrl.groupTracks[node.entity.id] ?? [];

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
      buildChildTrack: (track, groupId, level) => _buildTrackNode(track, groupId, level),
      tracks: tracks,
    );
  }

  Widget _buildTrackNode(GroupedTrackMetadataItem track, int groupId, int level) {
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
      onMoveToGroup: (trackItem, currentGroupId) => _handleMoveTrackToGroup(trackItem, currentGroupId),
    );
  }

  Widget _buildGroupsTable() {
    final theme = CustomThemeProvider.of(context);

    List<GroupNode> currentNodes;
    List<GroupedTrackMetadataItem> currentTracks = [];

    if (_treeCtrl.currentNavigationGroupId == null || _treeCtrl.currentNavigationGroupId == 0) {
      currentNodes = _treeCtrl.nodes;
      currentTracks = _treeCtrl.groupTracks[0] ?? [];
    } else {
      final activeParentNode = _treeCtrl.findNodeById(_treeCtrl.currentNavigationGroupId!);
      currentNodes = activeParentNode?.subGroups ?? [];
      currentTracks = _treeCtrl.groupTracks[_treeCtrl.currentNavigationGroupId!] ?? [];
    }

    if (_treeCtrl.searchQuery.isNotEmpty) {
      currentNodes = _treeCtrl.filterNodes(currentNodes, _treeCtrl.searchQuery);
      currentTracks = currentTracks.where((t) =>
      t.title.toLowerCase().contains(_treeCtrl.searchQuery) ||
          t.filePath.toLowerCase().contains(_treeCtrl.searchQuery)).toList();
    }

    final totalItems = currentNodes.length + currentTracks.length;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackgroundColor,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Music Groups Items',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold, color: theme.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined),
                color: theme.primaryColor,
                tooltip: 'Add Group',
                onPressed: () async {
                  if (_treeCtrl.currentNavigationGroupId == null || _treeCtrl.currentNavigationGroupId == 0) {
                    await _handleRootGroupCreation();
                  } else {
                    final parentNode = _treeCtrl.findNodeById(_treeCtrl.currentNavigationGroupId!);
                    if (parentNode != null) await _handleAddSubgroup(parentNode);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const double minTableWidth = 550.0;
                final double tableWidth = constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth;

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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            child: Row(
                              children: [
                                if (widget.isSelectionMode) ...[
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Checkbox(
                                      value: widget.areAllSelected,
                                      activeColor: theme.primaryColor,
                                      onChanged: (_) => widget.onToggleSelectAll(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                                Expanded(
                                  flex: 5,
                                  child: Text('GROUP / TRACK TITLE', style: _headerTextStyle(theme)),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text('ALBUM', style: _headerTextStyle(theme)),
                                ),
                                const SizedBox(width: 32),
                              ],
                            ),
                          ),
                          Divider(height: 1, thickness: 1, color: theme.outerBackgroundColor),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              controller: widget.scrollController,
                              padding: EdgeInsets.zero,
                              itemCount: totalItems,
                              itemBuilder: (context, index) {
                                if (index < currentNodes.length) {
                                  return _buildGroupNode(currentNodes[index], 0);
                                }
                                final trackIndex = index - currentNodes.length;
                                final track = currentTracks[trackIndex];
                                final targetGroupId = _treeCtrl.currentNavigationGroupId ?? 0;
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

  TextStyle _headerTextStyle(IAppTheme theme) {
    return TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w700,
      color: theme.textMuted,
      letterSpacing: 0.8,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GroupListSearchBar(
          onChanged: (q) => setState(() => _treeCtrl.searchQuery = q),
        ),
        const SizedBox(height: 10),
        GroupListNavigationBar(
          currentNavigationGroupId: _treeCtrl.currentNavigationGroupId,
          breadcrumbs: _treeCtrl.navigationBreadcrumb,
          onBack: () {
            if (_treeCtrl.navigateHistory.isNotEmpty) _treeCtrl.navigateHistory.removeLast();
            final to = _treeCtrl.navigateHistory.lastOrNull;
            if (_treeCtrl.navigateHistory.isNotEmpty) _treeCtrl.navigateHistory.removeLast();
            _navigateToGroup(to);
          },
          onNavigate: _navigateToGroup,
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildGroupsTable()),
      ],
    );
  }
}
