import 'package:flutter/material.dart';

import '../../themes/theme_provider.dart';

/// Item metadata for [SegmentedControl].
class SegmentedControlItem {
  final String label;
  final IconData? icon;

  const SegmentedControlItem({
    required this.label,
    this.icon,
  });
}

/// Generic segmented control widget with responsive layout & sliding indicator.
class SegmentedControl extends StatelessWidget {
  final List<SegmentedControlItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelectedIndexChanged;
  final bool showLabels;
  final double height;

  const SegmentedControl({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelectedIndexChanged,
    this.showLabels = true,
    this.height = 38.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final totalCount = items.length;

    if (totalCount == 0) return const SizedBox.shrink();

    return Container(
      height: height,
      padding: const EdgeInsets.all(4.0),
      decoration: BoxDecoration(
        color: theme.textPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double totalAvailableWidth = constraints.maxWidth;
          final double tabWidth = totalAvailableWidth / totalCount;

          return Stack(
            children: [
              // Sliding Background Indicator using precise offset
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.fastOutSlowIn,
                left: selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),

              // Interactive Tab Items
              Row(
                children: List.generate(totalCount, (index) {
                  final item = items[index];
                  return Expanded(
                    child: _SegmentTab(
                      label: item.label,
                      icon: item.icon,
                      isSelected: selectedIndex == index,
                      showLabel: showLabels,
                      onTap: () => onSelectedIndexChanged(index),
                      theme: theme,
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;
  final dynamic theme;

  const _SegmentTab({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.showLabel,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF635BFF);
    final inactiveColor = theme.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Dynamically hide label if available tab width can't fit icon + text comfortably
              final bool canFitText = constraints.maxWidth > 65.0;
              final bool shouldRenderLabel = showLabel && canFitText;

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null)
                    Icon(
                      icon,
                      size: 14.0,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  if (shouldRenderLabel) ...[
                    if (icon != null) const SizedBox(width: 4.0),
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
