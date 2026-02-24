import 'package:flutter/material.dart';

/// Centralized app color constants.
///
/// Prevents hardcoding colors across the app and ensures consistency.

class AppColors {
  /// Private constructor to prevent instantiation.
  AppColors._();

  // Brand Colors
  static const Color primary = Color(0xFFC03355);
  static const Color secondaryColor = Color(0xFFffffff);

  // Base Colors
  static const Color dark = Color(0xFF101010);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF3F3F3);
  static const Color scafoldbackground = Color(0xFFF5F7FA);

  // Background & Surface
  static const Color background = lightGrey;
  static const Color surface = white;
  static const Color surfaceDark = dark;

  // Text Colors
  static const Color textPrimary = dark;
  static const Color textSecondary = Color(0xFF666666);
  static const Color textOnPrimary = white;

  // Info Colors
  static const Color infoIcon = Color(0xFF90CAF9);
  static const Color infoIconBackground = Color(0x332196F3);
  static const Color infoBackgroundDark = Color(0xFF2D3748);
  static const Color infoBackgroundLight = Color(0xFF4A5568);

  // Success Colors
  static const Color successIcon = Color(0xFF81C784);
  static const Color successIconBackground = Color(0x334CAF50);
  static const Color successBackgroundDark = Color(0xFF2D4A3D);
  static const Color successBackgroundLight = Color(0xFF4A6B5A);

  // Warning Colors
  static const Color warningIcon = Color(0xFFFFB74D);
  static const Color warningIconBackground = Color(0x33FF9800);
  static const Color warningBackgroundDark = Color(0xFF4A3D2D);
  static const Color warningBackgroundLight = Color(0xFF6B5A4A);

  // Error Colors
  static const Color errorIcon = Color(0xFFE57373);
  static const Color errorIconBackground = Color(0x33F44336);
  static const Color errorBackgroundDark = Color(0xFF4A2D2D);
  static const Color errorBackgroundLight = Color(0xFF6B4A4A);

  // Semantic Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Utility Colors
  static const Color transparent = Colors.transparent;
  static const Color divider = Color(0xFFE0E0E0);
  static const Color shadow = Color(0x1A000000);
}
