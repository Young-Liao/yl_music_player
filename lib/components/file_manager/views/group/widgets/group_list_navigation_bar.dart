import 'package:flutter/material.dart';
import '../../../../../themes/theme_provider.dart';
import '../../../../../utils/data_structures/group.dart';

class GroupListNavigationBar extends StatelessWidget {
  final int? currentNavigationGroupId;
  final List<GroupNode> breadcrumbs;
  final VoidCallback onBack;
  final ValueChanged<GroupNode?> onNavigate;

  const GroupListNavigationBar({
    super.key,
    required this.currentNavigationGroupId,
    required this.breadcrumbs,
    required this.onBack,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);
    final bool canGoBack =
        currentNavigationGroupId != null && currentNavigationGroupId != 0;

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
              side: BorderSide(
                color: theme.textMuted.withValues(alpha: 0.3),
              ),
            ),
          ),
          onPressed: canGoBack ? onBack : null,
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
              border: Border.all(
                color: theme.textMuted.withValues(alpha: 0.3),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return _buildLeftAlignedBreadcrumbs(
                  theme,
                  constraints.maxWidth,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftAlignedBreadcrumbs(dynamic theme, double maxWidth) {
    // 1. Root Segment Widget
    final Widget rootItem = InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => onNavigate(null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.home_outlined,
              size: 16,
              color: currentNavigationGroupId == null
                  ? theme.primaryColor
                  : theme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              'Root',
              style: TextStyle(
                fontSize: 13,
                color: currentNavigationGroupId == null
                    ? theme.primaryColor
                    : theme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    if (breadcrumbs.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [rootItem],
      );
    }

    // Measure approximate available space for items after Root
    // Subtracting ~75px for Root icon/text + padding
    double remainingWidth = maxWidth - 75.0;

    List<Widget> visibleItems = [rootItem];

    // Check if we need truncation (Root / ... / Current)
    bool needTruncation = false;

    // Estimate total required width for full chain
    double totalChainWidth = 0;
    for (final b in breadcrumbs) {
      totalChainWidth += (b.entity.name.length * 8.0) + 24.0; // Approx character width + padding/slash
    }

    if (totalChainWidth > remainingWidth && breadcrumbs.length > 2) {
      needTruncation = true;
    }

    if (!needTruncation) {
      // Render full left-aligned list
      for (int i = 0; i < breadcrumbs.length; i++) {
        final bool isLast = i == breadcrumbs.length - 1;
        visibleItems.add(_buildSeparator(theme));
        visibleItems.add(_buildBreadcrumbItem(
          theme: theme,
          node: breadcrumbs[i],
          isLast: isLast,
        ));
      }
    } else {
      // Render truncated list: Root / ... / Last Node
      visibleItems.add(_buildSeparator(theme));
      visibleItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '...',
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      visibleItems.add(_buildSeparator(theme));
      visibleItems.add(_buildBreadcrumbItem(
        theme: theme,
        node: breadcrumbs.last,
        isLast: true,
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: visibleItems,
    );
  }

  Widget _buildSeparator(dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '/',
        style: TextStyle(
          fontSize: 13,
          color: theme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBreadcrumbItem({
    required dynamic theme,
    required GroupNode node,
    required bool isLast,
  }) {
    Widget itemWidget = InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => onNavigate(node),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          node.entity.name,
          maxLines: 1,
          overflow: isLast ? TextOverflow.ellipsis : TextOverflow.clip,
          style: TextStyle(
            fontSize: 13,
            color: isLast ? theme.primaryColor : theme.textSecondary,
            fontWeight: isLast ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );

    // If it's the last element, wrap in Flexible so it can truncate gracefully if container is small
    return isLast ? Flexible(child: itemWidget) : itemWidget;
  }
}
