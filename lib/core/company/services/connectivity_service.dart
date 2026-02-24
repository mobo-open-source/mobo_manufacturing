import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring internet connectivity and server reachability.
///
/// Provides:
/// - Internet availability stream
/// - Server availability stream
/// - Helper validation methods for network/server checks
class ConnectivityService {
  ConnectivityService._();

  /// Singleton instance
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  /// Emits internet availability changes
  final StreamController<bool> _internetController =
      StreamController<bool>.broadcast();

  /// Emits server reachability changes
  final StreamController<bool> _serverController =
      StreamController<bool>.broadcast();
  bool _lastInternetReachable = false;
  bool _lastServerReachable = true;
  String? _currentServerUrl;

  Stream<bool> get onInternetChanged => _internetController.stream;

  Stream<bool> get onServerChanged => _serverController.stream;

  /// Starts listening to connectivity changes and probes network + server.
  void startMonitoring() {
    _probeInternet();
    _probeServer();
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      await _probeInternet();
      await _probeServer();
    });
  }

  /// Checks internet access and emits change if status differs.
  Future<void> _probeInternet() async {
    final reachable = await hasInternetAccess();
    if (reachable != _lastInternetReachable) {
      _lastInternetReachable = reachable;
      _internetController.add(reachable);
    }
  }

  /// Checks server reachability and emits change if status differs.
  Future<void> _probeServer() async {
    final url = _currentServerUrl;
    if (url == null) return;
    if (!_lastInternetReachable) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
      return;
    }
    try {
      await ensureServerReachable(url);
      if (_lastServerReachable != true) {
        _lastServerReachable = true;
        _serverController.add(true);
      }
    } catch (_) {
      if (_lastServerReachable != false) {
        _lastServerReachable = false;
        _serverController.add(false);
      }
    }
  }

  /// Checks if device has any network connection (WiFi / Mobile).
  Future<bool> isNetworkAvailable() async {
    final List<ConnectivityResult> results = await _connectivity
        .checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Verifies real internet access using DNS lookup.
  Future<bool> hasInternetAccess({String host = 'example.com'}) async {
    try {
      final result = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Ensures internet availability or throws exception.
  Future<void> ensureInternetOrThrow() async {
    final net = await isNetworkAvailable();
    if (!net) {
      throw NoInternetException(
        'No network connection. Please check Wi‑Fi or mobile data.',
      );
    }
    final online = await hasInternetAccess();
    if (!online) {
      throw NoInternetException(
        'Connected to a network but no internet access.',
      );
    }
  }

  /// Ensures server host is reachable or throws exception.
  Future<void> ensureServerReachable(String serverUrl) async {
    try {
      final uri = Uri.parse(serverUrl);
      final host = uri.host.isNotEmpty ? uri.host : serverUrl;
      final res = await InternetAddress.lookup(
        host,
      ).timeout(const Duration(seconds: 3));
      if (res.isEmpty) {
        throw ServerUnreachableException('Unable to reach server host: $host');
      }
    } on Exception {
      throw ServerUnreachableException(
        'Unable to reach server. Please verify the URL and network.',
      );
    }
  }

  /// Updates server URL used for reachability monitoring.
  void setCurrentServerUrl(String? serverUrl) {
    _currentServerUrl = serverUrl;
    _probeServer();
  }

  /// Returns last known server reachability state.
  bool get lastKnownServerReachable =>
      _currentServerUrl == null ? true : _lastServerReachable;
}

/// Exception thrown when internet is unavailable.
class NoInternetException implements Exception {
  final String message;

  NoInternetException(this.message);

  @override
  String toString() => 'NoInternetException: $message';
}

/// Exception thrown when server cannot be reached.
class ServerUnreachableException implements Exception {
  final String message;

  ServerUnreachableException(this.message);

  @override
  String toString() => 'ServerUnreachableException: $message';
}
