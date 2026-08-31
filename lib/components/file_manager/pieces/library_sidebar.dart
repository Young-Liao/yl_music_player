import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

class LibrarySidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final dynamic theme;

  const LibrarySidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.cardBackgroundColor.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LIBRARY',
            style: TextStyle(
              fontSize: 11.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.textMuted,
            ),
          ),
          const SizedBox(height: 12.0),
          _SidebarItem(
            icon: BootstrapIcons.music_note_list,
            label: 'Music Files',
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
            theme: theme,
          ),
          const SizedBox(height: 4.0),
          _SidebarItem(
            icon: BootstrapIcons.list_task,
            label: 'Playlists',
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
            theme: theme,
          ),
          const SizedBox(height: 4.0),
          _SidebarItem(
            icon: BootstrapIcons.folder2_open,
            label: 'Groups',
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final dynamic theme;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final activeBgColor = theme.primaryColor.withValues(alpha: 0.12);
    final activeColor = theme.primaryColor;
    final inactiveColor = theme.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.0),
        hoverColor: theme.textPrimary.withValues(alpha: 0.04),
        splashColor: theme.primaryColor.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: isSelected ? activeBgColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16.0,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(width: 10.0),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : theme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}