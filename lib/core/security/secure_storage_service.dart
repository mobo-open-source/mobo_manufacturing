import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides secure storage operations for saving and retrieving user passwords.
///
/// Uses platform secure storage:
/// - Android: EncryptedSharedPreferences
/// - iOS: Keychain (first unlock of device)
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Generates a unique key for storing password based on
  /// server URL, database name, and username.
  static String _passwordKey(String url, String database, String username) {
    return 'odoo_pass_${url}_$database}_$username';
  }

  /// Saves password securely for given server, database and user.
  Future<void> savePassword({
    required String url,
    required String database,
    required String username,
    required String password,
  }) async {
    final key = _passwordKey(url, database, username);
    await _storage.write(key: key, value: password);
  }

  /// Retrieves stored password if available, otherwise returns null.
  Future<String?> getPassword({
    required String url,
    required String database,
    required String username,
  }) async {
    final key = _passwordKey(url, database, username);
    return await _storage.read(key: key);
  }

  /// Deletes stored password for specific server, database and user.
  Future<void> deletePassword({
    required String url,
    required String database,
    required String username,
  }) async {
    final key = _passwordKey(url, database, username);
    await _storage.delete(key: key);
  }

  /// Deletes all stored passwords from secure storage.
  Future<void> deleteAllPasswords() async {
    await _storage.deleteAll();
  }
}
