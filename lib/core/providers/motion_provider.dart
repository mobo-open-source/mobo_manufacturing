import 'package:flutter/cupertino.dart';

/// Controls motion/animation accessibility preference across the app.
///
/// Used for:
/// - Reducing animations
/// - Supporting accessibility users who prefer less motion
/// - Disabling heavy transitions if needed
class MotionProvider extends ChangeNotifier {
  /// When true → animations should be reduced or disabled.
  bool _reduceMotion = false;

  /// Returns current motion preference.
  bool get reduceMotion => _reduceMotion;

  /// Updates motion preference and notifies UI listeners.
  ///
  /// Example usage:
  /// - Disable page transition animations
  /// - Reduce Lottie animation speed
  /// - Remove parallax or shimmer effects
  void setReduceMotion(bool value) {
    _reduceMotion = value;
    notifyListeners();
  }
}
