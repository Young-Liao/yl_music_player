import 'package:flutter/material.dart';
import '../../../themes/theme_provider.dart';
import '../../navigation/app_router.dart';

class AppBottomNavigationBar extends StatelessWidget {
  const AppBottomNavigationBar({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = CustomThemeProvider.of(context);

    return ListenableBuilder(
      listenable: AppRouter.instance,
      builder: (context, _) {
        final currentRoute = AppRouter.instance.currentRoute;
        final currentIndex = AppRoute.values.indexOf(currentRoute);

        return LayoutBuilder(
          builder: (context, constraints) {
            // Only render the bottom bar on narrow viewports (< 600px)
            if (constraints.maxWidth >= 696) {
              return const SizedBox.shrink();
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.cardBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.textMuted.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          );
                        }
                        return TextStyle(
                          color: theme.textSecondary,
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
                      onDestinationSelected: (index) {
                        AppRouter.instance.goToRoute(AppRoute.values[index]);
                      },
                      backgroundColor: Colors.transparent,
                      indicatorColor: theme.primaryColor.withValues(
                        alpha: 0.15,
                      ),
                      elevation: 0,
                      height: 56,
                      destinations: AppRoute.values.map((route) {
                        final bool isSelected = route == currentRoute;
                        return NavigationDestination(
                          icon: Icon(
                            route.icon,
                            color: isSelected
                                ? theme.primaryColor
                                : theme.textSecondary,
                          ),
                          label: route.label,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
