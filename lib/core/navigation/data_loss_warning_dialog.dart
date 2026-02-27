import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../globals.dart';

/// Dialog shown when user is about to lose unsaved data.
///
/// Common use cases:
/// • Leaving form without saving
/// • Navigating away with unsaved edits
/// • Switching company / workspace with pending changes
///
/// Returns:
/// • true  → User confirmed action (Leave / Discard)
/// • false → User cancelled action (Stay / Keep Editing)
/// • null  → Dialog dismissed (rare case)
class DataLossWarningDialog extends StatelessWidget {
  final String title;
  final String message;

  /// Text shown on confirm action button.
  final String confirmText;

  /// Text shown on cancel button.
  final String cancelText;

  const DataLossWarningDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Leave',
    this.cancelText = 'Stay',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    /// Primary color adapts for dark mode contrast
    final primaryColor = isDark ? Colors.white : AppStyle.primaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Warning Icon Container
            Container(
              decoration: BoxDecoration(
                color: isDark ? primaryColor : primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(16),
              child: Icon(
                HugeIcons.strokeRoundedAlert02,
                color: isDark ? Colors.black : primaryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            /// Title Text
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            /// Message Text
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300]! : Colors.grey[700]!,
              ),
            ),
            const SizedBox(height: 24),

            /// Action Buttons Row
            Row(
              children: [
                /// Cancel Button (Stay / Keep Editing)
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      cancelText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[300]! : Colors.grey[700]!,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                /// Confirm Button (Leave / Discard)
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      confirmText,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to show dialog easily.
  ///
  /// Example:
  /// ```dart
  /// final shouldLeave = await DataLossWarningDialog.show(
  ///   context: context,
  ///   title: "Discard Changes?",
  ///   message: "You have unsaved changes.",
  /// );
  /// ```
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Discard',
    String cancelText = 'Keep Editing',
  }) {
    return showDialog<bool>(
      context: context,

      /// Prevents closing dialog by tapping outside
      barrierDismissible: false,
      builder: (_) => DataLossWarningDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }
}
