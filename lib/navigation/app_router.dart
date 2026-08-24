import 'package:flutter/material.dart';

class AppRouter extends ChangeNotifier {
  static final AppRouter instance = AppRouter._();
  AppRouter._();

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  void goToPage(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }
}