import 'package:flutter/material.dart';
import 'background_timer_service.dart';

/// A `WidgetsBindingObserver` that listens to Flutter app lifecycle events
/// and forwards them to `BackgroundTimerService` to pause/resume work order timers.
///
/// Purpose:
/// • When app goes to background → tells timer service to stop real-time counting
///   (but keeps state persisted so it can resume later)
/// • When app returns to foreground → reloads persisted timers and resumes updates
///
/// This ensures accurate duration tracking even when the app is minimized or the
/// device is locked, while avoiding unnecessary CPU usage in the background.
class AppLifecycleService extends WidgetsBindingObserver {
  final BackgroundTimerService _timerService;

  AppLifecycleService(this._timerService);

  /// Registers this observer with Flutter's `WidgetsBinding` so it receives
  /// lifecycle events.
  ///
  /// Should be called once during app initialization (e.g. in `initState` of
  /// a top-level widget or service initializer).
  void startListening() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Removes this observer from `WidgetsBinding` to stop receiving lifecycle events.
  ///
  /// Should be called when the service is no longer needed (e.g. in `dispose`
  /// of the widget/service that owns this instance).
  void stopListening() {
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Called automatically by Flutter whenever the app lifecycle state changes.
  ///
  /// Delegates the state change to `BackgroundTimerService` so it can:
  /// - pause counting when going to background/inactive
  /// - resume and reload persisted timers when returning to foreground
  ///
  /// @param state The new `AppLifecycleState` (resumed, inactive, paused, detached, hidden)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _timerService.onAppLifecycleStateChanged(state);
  }
}