import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../globals.dart';
import 'package:hive_ce/hive.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../LoginPage/services/storage_service.dart';
import '../../MO/pages/MoList/service/hive/models.dart';
import '../../shared/widgets/snackbar.dart';

/// Logout confirmation dialog.
///
/// Features:
/// • Confirms user logout action
/// • Shows loading overlay during logout process
/// • Clears SharedPreferences session data (preserving onboarding flags)
/// • Stops background services
/// • Clears offline Hive database data
/// • Navigates user back to login screen
class LogoutDialog extends StatefulWidget {
  /// Storage service used for managing session/local storage.
  final StorageService storageService;

  const LogoutDialog({super.key, required this.storageService});

  @override
  State<LogoutDialog> createState() => _LogoutDialogState();
}

class _LogoutDialogState extends State<LogoutDialog> {
  /// Controls logout loading state for button and overlay.
  bool isLogoutLoading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Confirm Logout",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
        ],
      ),
      /// Confirmation message content.
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 15),
          Text(
            'Are you sure you want to log out? Your session will be ended.',
            style: TextStyle(fontWeight: FontWeight.normal, fontSize: 18),
          ),
        ],
      ),
      /// Dialog action buttons.
      actions: [
        Row(
          children: [
            /// Cancel button — closes dialog.
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                  side: BorderSide(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  "Cancel",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            /// Logout button — triggers logout process.
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _performLogout(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.red[700]
                      : Theme.of(context).colorScheme.error,
                  foregroundColor: isDark
                      ? Colors.white
                      : Theme.of(context).colorScheme.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: isDark ? 0 : 3,
                ),
                child: isLogoutLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    :  Text(
                  'Log Out',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Performs complete logout flow.
  ///
  /// Steps:
  /// 1. Shows loading overlay
  /// 2. Clears SharedPreferences session data (preserves onboarding flags)
  /// 3. Stops background services
  /// 4. Clears Hive offline data (products, BOM, users, work centers)
  /// 5. Navigates to login screen
  Future<void> _performLogout(BuildContext context) async {
    setState(() => isLogoutLoading = true);

    /// Show non-dismissible loading dialog.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.fourRotatingDots(
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  "Logging out...",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  "Please wait while we process your request.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );

    await Future.delayed(const Duration(seconds: 2));

    final prefs = await SharedPreferences.getInstance();

    /// Preserve important onboarding and history flags.
    List<String> urlHistory = prefs.getStringList('urlHistory') ?? [];
    bool isGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

    /// Clear session data.
    await prefs.clear();

    /// Restore preserved keys.
    await prefs.setStringList('urlHistory', urlHistory);
    await prefs.setBool('hasSeenGetStarted', isGetStarted);

    /// Stop background service.
    await stopBackgroundService();

    /// Clear Hive offline storage.
    final productBox = Hive.isBoxOpen('products')
        ? Hive.box<HiveProduct>('products')
        : await Hive.openBox<HiveProduct>('products');
    final bomBox = Hive.isBoxOpen('bom')
        ? Hive.box<HiveBom>('bom')
        : await Hive.openBox<HiveBom>('bom');
    final userBox = Hive.isBoxOpen('users')
        ? Hive.box<HiveUserModel>('users')
        : await Hive.openBox<HiveUserModel>('users');
    final workCenterBox = Hive.isBoxOpen('workCenters')
        ? Hive.box<HiveWorkCenter>('workCenters')
        : await Hive.openBox<HiveWorkCenter>('workCenters');

    await productBox.clear();
    await bomBox.clear();
    await userBox.clear();
    await workCenterBox.clear();

    if (context.mounted) {
      Navigator.pop(context);

      /// Navigate to login and remove navigation stack.
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      CustomSnackbar.showSuccess(context, 'Logged out successfully');
    }

    setState(() => isLogoutLoading = false);
  }

  /// Stops Flutter background service if running.
  Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(seconds: 1));
    } else {}
  }
}
