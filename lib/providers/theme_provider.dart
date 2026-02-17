import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadTheme();
  }

  // Load theme preference from storage
  void _loadTheme() {
    _isDarkMode = _storage.getThemeMode();
  }

  // Toggle theme
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storage.saveThemeMode(_isDarkMode);
    notifyListeners();
  }

  // Set theme explicitly
  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    await _storage.saveThemeMode(_isDarkMode);
    notifyListeners();
  }
}
