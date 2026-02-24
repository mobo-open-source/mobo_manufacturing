import 'dart:async';

/// Global event bus used to notify listeners when company data needs refresh.
///
/// Uses broadcast stream so multiple widgets/services can listen.

class CompanyRefreshBus {
  /// Broadcast controller to allow multiple subscribers.
  static final _controller = StreamController<void>.broadcast();

  /// Stream to listen for refresh events.
  static Stream<void> get stream => _controller.stream;

  /// Triggers refresh event to all listeners.
  static void notify() {
    _controller.add(null);
  }
}