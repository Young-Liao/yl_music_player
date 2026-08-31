import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import '../../window/segmented_control.dart';

/// Segmented control designed to toggle between library tabs in narrow viewports.
class LibrarySegmentedControl extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const LibrarySegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      SegmentedControlItem(
        label: 'Music Files',
        icon: BootstrapIcons.music_note_list,
      ),
      SegmentedControlItem(
        label: 'Playlists',
        icon: BootstrapIcons.list_task,
      ),
      SegmentedControlItem(
        label: 'Groups',
        icon: BootstrapIcons.folder2_open,
      ),
    ];

    return SegmentedControl(
      items: items,
      selectedIndex: selectedIndex,
      onSelectedIndexChanged: onItemSelected,
      showLabels: true,
      height: 36.0,
    );
  }
}