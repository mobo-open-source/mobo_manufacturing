/// Singleton manager that tracks real-time elapsed duration for multiple work orders.
///
/// Features:
/// - Tracks start time and accumulated elapsed time per work order ID
/// - Supports start / pause / stop / query operations
/// - Handles already-elapsed time when resuming a paused work order
/// - Thread-safe for UI usage (single isolate)
///
/// Usage example:
/// ```dart
/// final timer = WorkOrderTimerManager();
///
/// // Start or resume
/// timer.start(workOrderId, existingElapsedDuration);
///
/// // Get current elapsed time (updates live)
/// final current = timer.getElapsed(workOrderId);
///
/// // Pause
/// timer.pause(workOrderId);
///
/// // Check if running
/// if (timer.isRunning(workOrderId)) { ... }
/// ```
class WorkOrderTimerManager {
  static final WorkOrderTimerManager _instance =
      WorkOrderTimerManager._internal();

  /// Factory constructor returns the single shared instance
  factory WorkOrderTimerManager() => _instance;

  WorkOrderTimerManager._internal();

  /// Map of work order ID → start time (only present when running)
  final Map<int, DateTime> _startTimes = {};

  /// Map of work order ID → accumulated elapsed time (before current run)
  final Map<int, Duration> _elapsedDurations = {};

  bool _isStarted = false;

  bool get isStarted => _isStarted;

  /// Starts (or resumes) timing for a work order.
  ///
  /// - If already running, this has no effect (safe to call multiple times)
  /// - `alreadyElapsed`: pass the previously accumulated duration if resuming
  void start(int id, Duration alreadyElapsed) {
    _startTimes[id] = DateTime.now();
    _elapsedDurations[id] = alreadyElapsed;
    _isStarted = true;
  }

  /// Pauses the timer for a specific work order.
  ///
  /// Adds the time elapsed since last start to the accumulated duration
  /// and removes the start time.
  void pause(int id) {
    if (_startTimes.containsKey(id)) {
      final elapsed = DateTime.now().difference(_startTimes[id]!);
      _elapsedDurations[id] =
          (_elapsedDurations[id] ?? Duration.zero) + elapsed;
      _startTimes.remove(id);
    }

    // Update global running state
    if (_startTimes.isEmpty) {
      _isStarted = false;
    }
  }

  /// Completely stops and clears timer data for a work order.
  ///
  /// Removes both start time and accumulated duration.
  void stop(int id) {
    _startTimes.remove(id);
    _elapsedDurations.remove(id);

    if (_startTimes.isEmpty) {
      _isStarted = false;
    }
  }

  /// Returns the **current** total elapsed duration for a work order.
  ///
  /// - If running: includes time since last start
  /// - If paused/stopped: returns accumulated duration only
  /// - If never started: returns Duration.zero
  Duration getElapsed(int id) {
    if (_startTimes.containsKey(id)) {
      final elapsed = DateTime.now().difference(_startTimes[id]!);
      return (_elapsedDurations[id] ?? Duration.zero) + elapsed;
    }
    return _elapsedDurations[id] ?? Duration.zero;
  }

  /// Checks whether a specific work order is currently running (has active timer)
  bool isRunning(int id) => _startTimes.containsKey(id);
}
