import 'dart:async';

/// A simple event bus used to broadcast profile refresh notifications across the app.
///
/// This class provides a centralized way to notify listeners whenever the user's
/// profile data has been updated (e.g. after editing profile, changing avatar,
/// updating settings, etc.). Components can subscribe to [onProfileRefresh]
/// to react to these changes without tight coupling.
class ProfileRefreshBus {
  static final _profileController = StreamController<void>.broadcast();

  /// Stream that emits an event whenever the profile should be refreshed.
  static Stream<void> get onProfileRefresh => _profileController.stream;

  /// Notifies all listeners that the profile data has changed and should be refreshed.
  static void notifyProfileRefresh() {
    _profileController.add(null);
  }
}
