import 'package:flutter/material.dart';

enum AppRoute {
  player(label: 'Player', icon: Icons.music_note_rounded),
  fileManager(label: 'File Manager', icon: Icons.folder_rounded),
  settings(label: 'Settings', icon: Icons.settings_rounded);

  final String label;
  final IconData icon;

  const AppRoute({required this.label, required this.icon});
}

class AppRouter extends ChangeNotifier {
  static final AppRouter instance = AppRouter._();
  AppRouter._();

  AppRoute _currentRoute = AppRoute.player;
  AppRoute get currentRoute => _currentRoute;

  void goToRoute(AppRoute route) {
    debugPrint("ROUTE TO: $route");
    if (_currentRoute == route) return;
    _currentRoute = route;
    notifyListeners();
  }
}
