import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/colors/app_colors.dart';
import '../../core/navigation/global_keys.dart';

/// Defines supported snackbar visual categories.
/// Used to decide icon, color and semantic meaning.
enum SnackbarType { info, success, warning, error }

/// Custom snackbar utility with consistent styling, icons, and colors.
///
/// Features:
///   - Four types: info, success, warning, error
///   - Floating style with rounded corners
///   - Icon + title + message layout
///   - Dark/light mode aware colors
///   - Safe to call from anywhere (uses global ScaffoldMessenger key)
///   - Convenience methods: showSuccess, showError, showInfo, showWarning
///
/// Usage:
/// ```dart
/// CustomSnackbar.showSuccess(context, 'Profile updated!');
/// CustomSnackbar.showError(context, 'Failed to connect to server');
/// ```
class CustomSnackbar {
  /// Shows a custom snackbar with title, message, type, and optional duration.
  ///
  /// Uses global `scaffoldMessengerKey` to display even from non-widget contexts.
  /// Safe: checks mounted state and wraps in post-frame callback.
  static void show({
    required BuildContext context,
    required String title,
    required String message,
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    try {
      // Prevent crashes if context is already unmounted
      if (!context.mounted) {
        return;
      }
      Theme.of(context);
    } catch (e) {
      return;
    }

    void tryShow() {
      try {
        final ScaffoldMessengerState? messenger =
            scaffoldMessengerKey.currentState;
        if (messenger == null || !messenger.mounted) {
          return;
        }

        BuildContext? themeCtx;
        try {
          themeCtx = navigatorKey.currentContext;
          if (themeCtx != null && themeCtx.mounted) {
            Theme.of(themeCtx);
          } else {
            themeCtx = null;
          }
        } catch (e) {
          themeCtx = null;
        }

        _showWithMessenger(messenger, themeCtx, title, message, type, duration);
      } catch (e) {}
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryShow());
  }

  static void _showWithMessenger(
      ScaffoldMessengerState messenger,
      BuildContext? themeContext,
      String title,
      String message,
      SnackbarType type,
      Duration duration,
      ) {
    try {
      if (!messenger.mounted) {
        return;
      }

      bool isDark = false;
      if (themeContext != null && themeContext.mounted) {
        try {
          isDark = Theme.of(themeContext).brightness == Brightness.dark;
        } catch (e) {
          isDark = false;
        }
      }
      final colors = _getColorsForType(type, isDark);

      if (!messenger.mounted) {
        return;
      }

      try {
        messenger.hideCurrentSnackBar();
      } catch (e) {}

      try {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(colors.icon, size: 16, color: colors.iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[300] : Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: colors.backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: duration,
            elevation: 8,
          ),
        );
      } catch (e) {}
    } catch (e) {}
  }

  /// Internal helper: returns icon + colors for each snackbar type
  static _SnackbarColors _getColorsForType(SnackbarType type, bool isDark) {
    switch (type) {
      case SnackbarType.info:
        return _SnackbarColors(
          icon: Icons.info_outline,
          iconColor: Colors.blue[300]!,
          iconBackgroundColor: Colors.blue.withOpacity(0.2),
          backgroundColor: isDark
              ? AppColors.infoBackgroundDark
              : AppColors.infoBackgroundLight,
        );
      case SnackbarType.success:
        return _SnackbarColors(
          icon: Icons.check_circle_outline,
          iconColor: Colors.green[300]!,
          iconBackgroundColor: Colors.green.withOpacity(0.2),
          backgroundColor: isDark
              ? AppColors.successBackgroundDark
              : AppColors.successBackgroundLight,
        );
      case SnackbarType.warning:
        return _SnackbarColors(
          icon: Icons.warning_outlined,
          iconColor: Colors.orange[300]!,
          iconBackgroundColor: Colors.orange.withOpacity(0.2),
          backgroundColor: isDark
              ? AppColors.warningBackgroundDark
              : AppColors.warningBackgroundLight,
        );
      case SnackbarType.error:
        return _SnackbarColors(
          icon: Icons.error_outline,
          iconColor: Colors.red[300]!,
          iconBackgroundColor: Colors.red.withOpacity(0.2),
          backgroundColor: isDark
              ? AppColors.errorBackgroundDark
              : AppColors.errorBackgroundLight,
        );
    }
  }

  // ────────────────────────────────────────────────
  // Convenience methods (most common usage)
  // ────────────────────────────────────────────────
  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      title: 'Success',
      message: message,
      type: SnackbarType.success,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      title: 'Error',
      message: message,
      type: SnackbarType.error,
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      title: 'Info',
      message: message,
      type: SnackbarType.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      title: 'Warning',
      message: message,
      type: SnackbarType.warning,
    );
  }
}

/// Internal color/icon bundle for each snackbar type
class _SnackbarColors {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color backgroundColor;

  _SnackbarColors({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.backgroundColor,
  });
}
