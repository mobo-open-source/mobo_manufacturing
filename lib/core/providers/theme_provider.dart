import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/utils/app_theme.dart';

/// Manages application theme (Light / Dark) and persists user preference locally.
///
/// Responsibilities:
/// - Load saved theme on app start
/// - Toggle between light and dark theme
/// - Persist selected theme using SharedPreferences
class ThemeProvider extends ChangeNotifier {
  /// Current theme mode used by the app.
  ThemeMode _themeMode = ThemeMode.light;

  /// Indicates whether theme loading from storage is completed.
  bool _isInitialized = false;

  ThemeProvider() {
    _initializeTheme();
  }

  /// Returns current theme mode.
  ThemeMode get themeMode => _themeMode;

  /// Returns true when theme has finished loading from storage.
  bool get isInitialized => _isInitialized;

  /// Initializes theme loading process.
  void _initializeTheme() {
    _isInitialized = true;

    _loadThemeMode();
  }

  /// Toggles between Light and Dark theme and saves preference.
  void toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    notifyListeners();
    await _saveThemeMode();
  }

  /// Saves selected theme mode to local storage.
  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  /// Loads saved theme mode from local storage.
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('theme_mode');
    if (mode == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  /// Returns light theme configuration.
  ThemeData get lightTheme => AppTheme.lightTheme;

  /// Returns dark theme configuration.
  ThemeData get darkTheme => AppTheme.darkTheme;
}
