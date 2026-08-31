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
    final bool canGoBack = currentNavigationGroupId != null && currentNavigationGroupId != 0;

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
              border: Border.all(color: theme.textMuted.withValues(alpha: 0.3)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(Icons.home_outlined, size: 14, color: theme.textSecondary),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => onNavigate(null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Root',
                        style: TextStyle(
                          fontSize: 13,
                          color: currentNavigationGroupId == null ? theme.primaryColor : theme.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  for (int i = 0; i < breadcrumbs.length; i++) ...[
                    Text(' / ', style: TextStyle(fontSize: 13, color: theme.textSecondary)),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => onNavigate(breadcrumbs[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          breadcrumbs[i].entity.name,
                          style: TextStyle(
                            fontSize: 13,
                            color: i == breadcrumbs.length - 1 ? theme.primaryColor : theme.textSecondary,
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
}