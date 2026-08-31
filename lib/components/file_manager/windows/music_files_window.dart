import 'package:flutter/material.dart';
import '../../../controllers/audio/audio_player_controller.dart';
import '../../../controllers/song_list/file_list_manager.dart';
import '../../../controllers/song_list/item_selection_controller.dart';
import '../../../pages/lan_transfer_dialog.dart';
import '../views/file_list_view.dart';
import '../pieces/file_manager_action_bar.dart';

final musicFilesWindowKey = GlobalKey<_MusicFilesWindowState>();

class MusicFilesWindow extends StatefulWidget {
  final AudioPlayerController audioController;
  final FileListManager fileListManager;
  final ItemSelectionController selectionController;
  final ValueChanged<String> onPlayTrack;
  final Function(int index)? onMoveToNext;
  final Function(int index)? onDelete;
  final bool isSelectionMode;
  final bool isSubjectiveSelection;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onConfirmSubjectiveSelection;

  // Replaced single upload callback with separate file and folder callbacks
  final VoidCallback onUploadFilesPressed;
  final VoidCallback onUploadFolderPressed;

  MusicFilesWindow({
    Key? key,
    required this.audioController,
    required this.fileListManager,
    required this.selectionController,
    required this.onPlayTrack,
    required this.onMoveToNext,
    required this.onDelete,
    required this.isSelectionMode,
    required this.isSubjectiveSelection,
    required this.onToggleSelectionMode,
    required this.onConfirmSubjectiveSelection,
    required this.onUploadFilesPressed,
    required this.onUploadFolderPressed,
  }) : super(key: key ?? musicFilesWindowKey);

  @override
  State<MusicFilesWindow> createState() => _MusicFilesWindowState();
}

class _MusicFilesWindowState extends State<MusicFilesWindow> {
  late final ScrollController _scrollController;

  bool get activeSelectionMode =>
      widget.isSelectionMode ||
      widget.selectionController.isLanTransferSelection;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.fileListManager.loadListFromDb().then((_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleBatchDelete() {
    if (!widget.selectionController.hasSelection) return;

    final sortedIndices = widget.selectionController.selectedIndices.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final index in sortedIndices) {
      widget.fileListManager.deleteItem(index);
    }

    widget.selectionController.clearSelection();
    widget.onToggleSelectionMode();
  }

  void _handleConfirmSelection() {
    if (widget.selectionController.isLanTransferSelection) {
      final selectedPaths = widget.selectionController.selectedIndices
          .map((i) => widget.fileListManager.songPaths[i])
          .toList();

      LanTransferDialog.show(context, selectedPaths);
      widget.selectionController.cancelLanTransferMode();
    } else {
      widget.onConfirmSubjectiveSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.selectionController,
      builder: (context, _) {
        final totalCount = widget.fileListManager.length;
        final areAllSelected = widget.selectionController.areAllSelected(
          totalCount,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isNarrow = constraints.maxWidth < 600;
            return Padding(
              padding: EdgeInsets.fromLTRB(isNarrow ? 0.0 : 20.0, 0.0, 0.0, 0.0),
              child: Column(
                children: [
                  FileManagerActionBar(
                    isActiveSelectionMode: activeSelectionMode,
                    isLanTransferSelection:
                        widget.selectionController.isLanTransferSelection,
                    isSubjectiveSelection: widget.isSubjectiveSelection,
                    selectedCount: widget.selectionController.selectedCount,
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
                  const SizedBox(height: 16.0),
                  Expanded(
                    child: FileListView(
                      fileListManager: widget.fileListManager,
                      audioController: widget.audioController,
                      onPlayTrack: widget.onPlayTrack,
                      scrollController: _scrollController,
                      onMoveToNext: widget.onMoveToNext ?? (index) {},
                      isSelectionMode: activeSelectionMode,
                      selectedIndices:
                          widget.selectionController.selectedIndices,
                      onToggleSelect:
                          widget.selectionController.toggleSelectIndex,
                      areAllSelected: areAllSelected,
                      onToggleSelectAll: () => widget.selectionController
                          .toggleSelectAll(totalCount),
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
