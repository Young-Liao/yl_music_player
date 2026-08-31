import 'package:flutter/material.dart';

import '../../../controllers/audio/audio_player_controller.dart';
import '../../../controllers/song_list/item_selection_controller.dart';
import '../../../main.dart';
import '../../../pages/lan_transfer_dialog.dart';
import '../../../themes/theme_provider.dart';
import '../../../utils/data_structures/group.dart';
import '../pieces/file_manager_action_bar.dart';
import '../views/group/group_list_view.dart';

final groupsWindowKey = GlobalKey<_GroupsWindowState>();

class GroupsWindow extends StatefulWidget {
  final AudioPlayerController audioController;
  final ItemSelectionController selectionController;
  final ValueChanged<String> onPlayTrack;
  final Function(String path)? onMoveToNext;
  final bool isSelectionMode;
  final bool isSubjectiveSelection;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onConfirmSubjectiveSelection;

  // Replaced single upload callback with separate file and folder callbacks
  final VoidCallback onUploadFilesPressed;
  final VoidCallback onUploadFolderPressed;

  GroupsWindow({
    Key? key,
    required this.audioController,
    required this.selectionController,
    required this.onPlayTrack,
    this.onMoveToNext,
    required this.isSelectionMode,
    required this.isSubjectiveSelection,
    required this.onToggleSelectionMode,
    required this.onConfirmSubjectiveSelection,
    required this.onUploadFilesPressed,
    required this.onUploadFolderPressed,
  }) : super(key: key ?? groupsWindowKey);

  @override
  State<GroupsWindow> createState() => _GroupsWindowState();
}

class _GroupsWindowState extends State<GroupsWindow> {
  final GlobalKey<GroupListViewState> _groupListViewKey = GlobalKey();
  late final ScrollController _scrollController;

  List<GroupNode> _rootNodes = [];
  bool _isLoading = true;

  final Set<GroupNode> _selectedGroups = {};
  final Set<String> _selectedTrackPaths = {};

  bool get activeSelectionMode =>
      widget.isSelectionMode ||
      widget.selectionController.isLanTransferSelection;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadGroupHierarchy();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupHierarchy() async {
    setState(() => _isLoading = true);
    final nodes = await groupManager.loadTwoLevelHierarchy();
    if (mounted) {
      setState(() {
        _rootNodes = nodes;
        _isLoading = false;
      });
    }
  }

  void _toggleGroupSelect(GroupNode group) {
    setState(() {
      if (_selectedGroups.contains(group)) {
        _selectedGroups.remove(group);
      } else {
        _selectedGroups.add(group);
      }
    });
  }

  void _toggleTrackSelect(String path) {
    setState(() {
      if (_selectedTrackPaths.contains(path)) {
        _selectedTrackPaths.remove(path);
      } else {
        _selectedTrackPaths.add(path);
      }
    });
  }

  bool get _areAllSelected {
    if (_rootNodes.isEmpty) return false;
    return _selectedGroups.length == _rootNodes.length;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_areAllSelected) {
        _selectedGroups.clear();
      } else {
        _selectedGroups.addAll(_rootNodes);
      }
    });
  }

  Future<List<String>> _extractSelectedTrackPaths() async {
    final state = _groupListViewKey.currentState;
    if (state != null) {
      return await state.extractAllSelectedTrackPaths();
    }
    return _selectedTrackPaths.toList();
  }

  Future<void> _handleBatchMoveToGroup() async {
    final state = _groupListViewKey.currentState;
    if (state != null) {
      await state.showBatchMoveDialog(
        onCompleteSelection: widget.onToggleSelectionMode,
      );
      setState(() {
        _selectedGroups.clear();
        _selectedTrackPaths.clear();
      });
    }
  }

  Future<void> _handleConfirmSelection() async {
    final paths = await _extractSelectedTrackPaths();

    if (!mounted) return;

    if (widget.selectionController.isLanTransferSelection) {
      LanTransferDialog.show(context, paths);
      widget.selectionController.cancelLanTransferMode();
    } else {
      widget.onConfirmSubjectiveSelection();
    }
  }

  void _handleBatchDelete() async {
    final pathsToDelete = await _extractSelectedTrackPaths();
    for (final path in pathsToDelete) {
      await groupManager.deleteTrackFromAllGroups(path);
    }
    setState(() {
      _selectedGroups.clear();
      _selectedTrackPaths.clear();
    });
    widget.selectionController.clearSelection();
    widget.onToggleSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return ListenableBuilder(
      listenable: widget.selectionController,
      builder: (context, _) {
        final selectedCount =
            _selectedGroups.length + _selectedTrackPaths.length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 700;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 0.0 : 20.0,
                0.0,
                0.0,
                0.0,
              ),
              child: Column(
                children: [
                  FileManagerActionBar(
                    isActiveSelectionMode: activeSelectionMode,
                    isLanTransferSelection:
                        widget.selectionController.isLanTransferSelection,
                    isSubjectiveSelection: widget.isSubjectiveSelection,
                    selectedCount: selectedCount,
                    onToggleSelection: () {
                      if (widget.selectionController.isLanTransferSelection) {
                        widget.selectionController.cancelLanTransferMode();
                      } else {
                        widget.onToggleSelectionMode();
                      }
                    },
                    onConfirmSelection: _handleConfirmSelection,
                    onBatchDelete: _handleBatchDelete,
                    onLanTransferPressed: () {
                      widget.selectionController.startLanTransferMode();
                    },
                    onUploadFilesPressed: widget.onUploadFilesPressed,
                    onUploadFolderPressed: widget.onUploadFolderPressed,
                  ),
                  if (activeSelectionMode) ...[
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.drive_file_move_outlined,
                            size: 16,
                          ),
                          label: const Text('MOVE TO GROUPS'),
                          onPressed: selectedCount > 0
                              ? _handleBatchMoveToGroup
                              : null,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: theme.primaryColor,
                            ),
                          )
                        : GroupListView(
                            key: _groupListViewKey,
                            rootNodes: _rootNodes,
                            scrollController: _scrollController,
                            onPlayTrack: widget.onPlayTrack,
                            onMoveToNext: widget.onMoveToNext ?? (path) {},
                            isSelectionMode: activeSelectionMode,
                            selectedGroups: _selectedGroups,
                            selectedTrackPaths: _selectedTrackPaths,
                            onToggleGroupSelect: _toggleGroupSelect,
                            onToggleTrackSelect: _toggleTrackSelect,
                            areAllSelected: _areAllSelected,
                            onToggleSelectAll: _toggleSelectAll,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
