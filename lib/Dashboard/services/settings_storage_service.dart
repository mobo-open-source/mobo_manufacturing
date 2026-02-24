import 'package:shared_preferences/shared_preferences.dart';

/// Service class responsible for handling local app settings storage.
///
/// Uses SharedPreferences for persistent key-value storage.
/// Supports storing and retrieving:
/// - Boolean values
/// - String values
/// - Integer values
/// - Double values
class SettingsStorageService {
  late SharedPreferences _prefs;

  /// Initializes the SharedPreferences instance.
  ///
  /// Must be called before accessing any storage methods.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Stores a boolean value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  /// - [value]: Boolean value to store
  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  /// Stores a string value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  /// - [value]: String value to store
  Future<void> setString(String key, String value) async => await _prefs.setString(key, value);

  /// Retrieves a stored string value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  ///
  /// Returns stored string or null if not found.
  String? getString(String key) => _prefs.getString(key);

  /// Stores an integer value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  /// - [value]: Integer value to store
  Future<void> setInt(String key, int value) async => await _prefs.setInt(key, value);

  /// Retrieves a stored integer value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  ///
  /// Returns stored integer or null if not found.
  int? getInt(String key) => _prefs.getInt(key);

  /// Stores a double value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  /// - [value]: Double value to store
  Future<void> setDouble(String key, double value) async => await _prefs.setDouble(key, value);

  /// Retrieves a stored double value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  ///
  /// Returns stored double or null if not found.
  double? getDouble(String key) => _prefs.getDouble(key);

  /// Retrieves a stored boolean value.
  ///
  /// Parameters:
  /// - [key]: Storage key
  ///
  /// Returns stored boolean or null if not found.
  bool? getBool(String key) {
    return _prefs.getBool(key);
  }

  /// Removes a specific stored key-value pair.
  ///
  /// Parameters:
  /// - [key]: Storage key to remove
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  /// Clears all stored preferences.
  ///
  /// Warning: This removes all locally stored app data.
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
