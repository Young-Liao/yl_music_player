import 'package:flutter/cupertino.dart';
import 'package:yl_music_player/components/window/segmented_control.dart';

import '../../navigation/app_router.dart';

/// Specialized wrapper for AppRoute navigation using [SegmentedControl].
class PageSegmentedControl extends StatelessWidget {
  final bool showLabels;

  const PageSegmentedControl({
    super.key,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final routes = AppRoute.values;

    return ListenableBuilder(
      listenable: AppRouter.instance,
      builder: (context, _) {
        final currentRoute = AppRouter.instance.currentRoute;
        final selectedIndex = routes.indexOf(currentRoute);

        return SegmentedControl(
          items: routes
              .map((r) => SegmentedControlItem(label: r.label, icon: r.icon))
              .toList(),
          selectedIndex: selectedIndex,
          showLabels: showLabels,
          onSelectedIndexChanged: (index) {
            AppRouter.instance.goToRoute(routes[index]);
          },
        );
      },
    );
  }
}

