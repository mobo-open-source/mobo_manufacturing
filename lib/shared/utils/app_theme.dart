import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Extension to adjust color brightness using HSL color space.
///
/// Allows increasing or decreasing lightness of a color safely
/// while keeping hue and saturation unchanged.
extension ColorBrightness on Color {
  /// Returns a new color with adjusted brightness.
  ///
  /// [brightnessDelta] → Positive = lighter, Negative = darker
  /// Value is clamped between 0.0 and 1.0.
  Color withBrightness(double brightnessDelta) {
    final hsl = HSLColor.fromColor(this);

    final newLightness = (hsl.lightness + brightnessDelta).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }
}

/// Centralized application theme configuration.
///
/// Contains:
/// • Primary & secondary brand colors
/// • Light theme configuration
/// • Dark theme configuration
/// • Common component theming (AppBar, Buttons, Inputs)
class AppTheme {

  /// Main brand color used across the app.
  static const Color primaryColor = Color(0xFFC03355);

  /// Secondary supporting color (usually backgrounds / contrast).
  static const Color secondaryColor = Color(0xFFffffff);

  /// Light mode theme configuration.
  ///
  /// Includes:
  /// • Manrope font
  /// • Seed-based color scheme
  /// • Light scaffold background
  /// • Styled AppBar, Buttons and Inputs
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );

  /// Dark mode theme configuration.
  ///
  /// Optimized for low-light UI with:
  /// • Dark scaffold background
  /// • Same brand color identity
  /// • Consistent component styling
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    fontFamily: GoogleFonts.manrope().fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
    ),
    scaffoldBackgroundColor: const Color(0xFF181A20),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );
}