import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service that tracks real-time durations of running work orders in the background.
///
/// Features:
/// • Runs a global 1-second timer to update durations of all active work orders
/// • Persists start times and base durations across app restarts via SharedPreferences
/// • Continues counting even when app is backgrounded (via persisted state + lifecycle handling)
/// • Broadcasts current durations via a `Stream<Map<int, Duration>>`
/// • Supports debug mode override (always counts even in background)
/// • Cleans up properly on dispose
///
/// Usage:
///   - Call `initialize()` once on app start
///   - Use `startWorkOrder()` / `stopWorkOrder()` when work order starts/finishes
///   - Listen to `durationStream` for real-time updates
///   - Call `onAppLifecycleStateChanged()` from `WidgetsBindingObserver`
class BackgroundTimerService {
  static final BackgroundTimerService _instance =
      BackgroundTimerService._internal();

  factory BackgroundTimerService() => _instance;

  BackgroundTimerService._internal();

  final Map<int, DateTime> _startTimes = {};
  final Map<int, Duration> _baseDurations = {};
  Timer? _globalTimer;

  /// Broadcast stream of current durations for all active work orders
  final StreamController<Map<int, Duration>> _durationController =
      StreamController<Map<int, Duration>>.broadcast();

  Stream<Map<int, Duration>> get durationStream => _durationController.stream;

  bool _isAppInForeground = true;

  /// Initializes the service:
  /// • Loads any previously persisted timers
  /// • Starts the global 1-second update timer
  void initialize() {
    _loadPersistedTimers();
    _startGlobalTimer();
  }

  /// Starts (or restarts) the global periodic timer that updates durations every second.
  /// Only counts when app is in foreground (unless in debug mode).
  void _startGlobalTimer() {
    if (_globalTimer != null) return;

    _globalTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isAppInForeground || kDebugMode) {
        _updateAllDurations();
      }
    });

    // Immediate update on start
    _updateAllDurations();
  }

  /// Calculates current total duration for every active work order and broadcasts it.
  void _updateAllDurations() {
    final now = DateTime.now();
    final currentDurations = <int, Duration>{};

    _startTimes.forEach((workOrderId, startTime) {
      final elapsedSinceStart = now.difference(startTime);
      final baseDuration = _baseDurations[workOrderId] ?? Duration.zero;
      final totalDuration = baseDuration + elapsedSinceStart;
      currentDurations[workOrderId] = totalDuration;
    });
    _durationController.add(currentDurations);
  }

  /// Starts tracking a new work order.
  ///
  /// @param workOrderId Unique ID of the work order
  /// @param baseDuration Optional already-accumulated duration from backend
  Future<void> startWorkOrder(
    int workOrderId, {
    Duration baseDuration = Duration.zero,
  }) async {
    final now = DateTime.now();
    _startTimes[workOrderId] = now;
    _baseDurations[workOrderId] = baseDuration;

    await _persistTimers();
    _updateAllDurations();
  }

  /// Stops tracking a work order and returns its final total duration.
  ///
  /// @param workOrderId ID of the work order to stop
  /// @return The final accumulated duration, or null if not running
  Future<Duration?> stopWorkOrder(int workOrderId) async {
    if (!_startTimes.containsKey(workOrderId)) {
      return null;
    }

    final totalDuration = _getCurrentDuration(workOrderId);

    _startTimes.remove(workOrderId);
    _baseDurations.remove(workOrderId);
    await _persistTimers();

    _updateAllDurations();

    return totalDuration;
  }

  /// Gets the current total duration for a specific work order (live calculation).
  Duration _getCurrentDuration(int workOrderId) {
    if (!_startTimes.containsKey(workOrderId)) return Duration.zero;

    final startTime = _startTimes[workOrderId]!;
    final now = DateTime.now();
    final elapsedSinceStart = now.difference(startTime);
    final baseDuration = _baseDurations[workOrderId] ?? Duration.zero;

    return baseDuration + elapsedSinceStart;
  }

  /// Returns a snapshot of current durations for all active work orders.
  Map<int, Duration> getCurrentDurations() {
    final now = DateTime.now();
    final durations = <int, Duration>{};

    _startTimes.forEach((workOrderId, startTime) {
      final elapsedSinceStart = now.difference(startTime);
      final baseDuration = _baseDurations[workOrderId] ?? Duration.zero;
      durations[workOrderId] = baseDuration + elapsedSinceStart;
    });

    return durations;
  }

  /// Checks if a work order is currently being timed.
  bool isWorkOrderRunning(int workOrderId) {
    return _startTimes.containsKey(workOrderId);
  }

  /// Returns the base (pre-existing) duration for a work order.
  Duration getBaseDuration(int workOrderId) {
    return _baseDurations[workOrderId] ?? Duration.zero;
  }

  /// Persists active timers (start times + base durations) to SharedPreferences.
  Future<void> _persistTimers() async {
    final prefs = await SharedPreferences.getInstance();

    final startTimeData = <String, dynamic>{};
    _startTimes.forEach((workOrderId, startTime) {
      startTimeData[workOrderId.toString()] = startTime.toIso8601String();
    });

    final baseDurationData = <String, dynamic>{};
    _baseDurations.forEach((workOrderId, duration) {
      baseDurationData[workOrderId.toString()] = duration.inSeconds;
    });

    final startTimeJson = jsonEncode(startTimeData);
    final baseDurationJson = jsonEncode(baseDurationData);

    await prefs.setString('active_timers_start', startTimeJson);
    await prefs.setString('active_timers_base', baseDurationJson);
  }

  /// Loads previously persisted timers from SharedPreferences on app start.
  Future<void> _loadPersistedTimers() async {
    final prefs = await SharedPreferences.getInstance();

    final startTimeJson = prefs.getString('active_timers_start');
    final baseDurationJson = prefs.getString('active_timers_base');

    Map<int, DateTime> loadedStartTimes = {};
    Map<int, Duration> loadedBaseDurations = {};

    if (startTimeJson != null && startTimeJson.isNotEmpty) {
      try {
        final Map<String, dynamic> startTimeData = jsonDecode(startTimeJson);
        startTimeData.forEach((key, value) {
          final workOrderId = int.tryParse(key);
          final startTime = DateTime.tryParse(value.toString());

          if (workOrderId != null && startTime != null) {
            loadedStartTimes[workOrderId] = startTime;
          }
        });
      } catch (e) {}
    }

    if (baseDurationJson != null && baseDurationJson.isNotEmpty) {
      try {
        final Map<String, dynamic> baseDurationData = jsonDecode(
          baseDurationJson,
        );
        baseDurationData.forEach((key, value) {
          final workOrderId = int.tryParse(key);
          final seconds = int.tryParse(value.toString());

          if (workOrderId != null && seconds != null) {
            loadedBaseDurations[workOrderId] = Duration(seconds: seconds);
          }
        });
      } catch (e) {
      }
    }

    _startTimes.addAll(loadedStartTimes);
    _baseDurations.addAll(loadedBaseDurations);

    // Broadcast current state after load
    _updateAllDurations();
  }

  /// Called by app lifecycle observer to pause/resume counting.
  ///
  /// When app goes to background: stops real-time counting (but persists state)
  /// When app returns to foreground: reloads persisted state and resumes
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (_isAppInForeground) {
      _loadPersistedTimers();
      _updateAllDurations();
    }
  }

  /// Cleans up resources (timer, maps, stream) when service is no longer needed.
  void dispose() {
    _globalTimer?.cancel();
    _startTimes.clear();
    _baseDurations.clear();
    _durationController.close();
  }

  /// Convenience getter: current duration for a specific work order.
  Duration getDurationForWorkOrder(int workOrderId) {
    return _getCurrentDuration(workOrderId);
  }

  /// Clears all active timers (both in memory and persisted).
  Future<void> clearAllTimers() async {
    _startTimes.clear();
    _baseDurations.clear();
    await _persistTimers();
    _updateAllDurations();
  }

  /// Set of all currently active (running) work order IDs.
  Set<int> get activeWorkOrderIds => _startTimes.keys.toSet();

  /// Number of currently running work orders.
  int get activeTimerCount => _startTimes.length;
}
