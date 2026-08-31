import 'package:flutter/material.dart';

import '../../../../../utils/data_structures/group.dart';

class NestedGroupPickerDialog extends StatefulWidget {
  final List<GroupNode> rootNodes;
  final int currentGroupId;

  const NestedGroupPickerDialog({
    super.key,
    required this.rootNodes,
    required this.currentGroupId,
  });

  @override
  State<NestedGroupPickerDialog> createState() =>
      _NestedGroupPickerDialogState();
}

class _NestedGroupPickerDialogState
    extends State<NestedGroupPickerDialog> {
  final Set<int> _expandedGroupIds = {0};

  late final GroupNode _rootGroupNode;

  @override
  void initState() {
    super.initState();

    _rootGroupNode = GroupNode(
      entity: GroupEntity(
        id: 0,
        name: 'Root Group',
        parentId: null,
      ),
      subGroups: widget.rootNodes,
      totalTracks: 0,
    );
  }

  void _toggleExpand(int groupId) {
    setState(() {
      if (_expandedGroupIds.contains(
        groupId,
      )) {
        _expandedGroupIds.remove(
          groupId,
        );
      } else {
        _expandedGroupIds.add(
          groupId,
        );
      }
    });
  }

  Widget _buildTreeNode(
      GroupNode node,
      int indentLevel,
      ) {
    final bool isExpanded =
    _expandedGroupIds.contains(
      node.entity.id,
    );

    final bool isCurrent =
        node.entity.id ==
            widget.currentGroupId;

    final bool hasChildren =
        node.subGroups.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius:
          BorderRadius.circular(8),
          child: InkWell(
            borderRadius:
            BorderRadius.circular(8),
            onTap: isCurrent
                ? null
                : () =>
                Navigator.of(context)
                    .pop(node),
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width:
                    indentLevel * 18.0,
                  ),

                  SizedBox(
                    width: 32,
                    height: 32,
                    child: hasChildren
                        ? IconButton(
                      padding:
                      EdgeInsets.zero,
                      constraints:
                      const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                        maxWidth: 32,
                        maxHeight: 32,
                      ),
                      icon:
                      AnimatedRotation(
                        turns:
                        isExpanded
                            ? 0.25
                            : 0.0,
                        duration:
                        const Duration(
                          milliseconds:
                          150,
                        ),
                        child: const Icon(
                          Icons
                              .chevron_right_rounded,
                          size: 20,
                        ),
                      ),
                      onPressed: () =>
                          _toggleExpand(
                            node.entity.id,
                          ),
                    )
                        : const SizedBox(),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Icon(
                    Icons.folder_rounded,
                    size: 20,
                    color: isCurrent
                        ? Colors.grey
                        : Colors.deepPurple,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      node.entity.name,
                      style: TextStyle(
                        fontWeight:
                        FontWeight.w600,
                        color: isCurrent
                            ? Colors.grey
                            : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                    ),
                  ),

                  if (node.entity.id != 0)
                    Text(
                      '${node.totalTracks} tracks',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey
                            .shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        if (hasChildren && isExpanded)
          ...node.subGroups.map(
                (sub) => _buildTreeNode(
              sub,
              indentLevel + 1,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Move to Group',
      ),
      content: SizedBox(
        width: 380,
        height: 380,
        child: ListView(
          children: [
            _buildTreeNode(
              _rootGroupNode,
              0,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
          ),
        ),
      ],
    );
  }
}
