import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import '../../navigation/app_router.dart';
import '../../themes/theme_provider.dart';

class PageSegmentedControl extends StatelessWidget {
  final bool showLabels;

  const PageSegmentedControl({
    super.key,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return ListenableBuilder(
      listenable: AppRouter.instance,
      builder: (context, _) {
        final selectedIndex = AppRouter.instance.currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: showLabels ? 250.0 : 88.0,
          height: 38.0,
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: theme.textPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Stack(
            children: [
              // Sliding White Indicator
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.fastOutSlowIn,
                alignment: selectedIndex == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1.0,
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
              ),

              // Tab Controls
              Row(
                children: [
                  Expanded(
                    child: _SegmentTab(
                      label: 'Player',
                      icon: BootstrapIcons.music_note,
                      isSelected: selectedIndex == 0,
                      showLabel: showLabels,
                      onTap: () => AppRouter.instance.goToPage(0),
                      theme: theme,
                    ),
                  ),
                  Expanded(
                    child: _SegmentTab(
                      label: 'File Manager',
                      icon: BootstrapIcons.folder,
                      isSelected: selectedIndex == 1,
                      showLabel: showLabels,
                      onTap: () => AppRouter.instance.goToPage(1),
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;
  final dynamic theme;

  const _SegmentTab({
    required this.label,
    required this.icon,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14.0,
              color: isSelected ? activeColor : inactiveColor,
            ),
            if (showLabel) ...[
              const SizedBox(width: 6.0),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
