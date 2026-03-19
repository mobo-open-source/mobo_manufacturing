import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';

/// Handles local persistence of session, login state, and multi-account data
/// using SharedPreferences.
class StorageService {

  /// Saves authenticated session details locally.
  ///
  /// Stores user, company, and server metadata required for session restore.
  Future<void> saveSession(SessionModel session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', session.userName ?? '');
    await prefs.setString('userLogin', session.userLogin ?? '');
    await prefs.setInt('userId', session.userId ?? 0);
    await prefs.setString('sessionId', session.sessionId);
    await prefs.setString('serverVersion', session.serverVersion ?? '');
    await prefs.setString('userLang', session.userLang ?? '');
    await prefs.setInt('partnerId', session.partnerId ?? 0);
    await prefs.setString('userTimezone', session.userTimezone ?? '');
    await prefs.setInt('companyId', session.companyId ?? 1);
    await prefs.setString('company_name', session.companyName ?? '');
    await prefs.setBool('isSystem', session.isSystem);
    await prefs.setInt('version', session.version ?? 0);
  }

  /// Saves login state and server connection details.
  ///
  /// Parameters:
  /// • isLoggedIn → Current login status
  /// • database → Active database name
  /// • url → Server base URL
  Future<void> saveLoginState({
    required bool isLoggedIn,
    required String database,
    required String url,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', isLoggedIn);
    await prefs.setString('database', database);
    await prefs.setString('url', url);
  }

  /// Retrieves stored login status and connection configuration.
  ///
  /// Returns:
  /// Map containing login flag, local auth flag, database, URL, and password.
  Future<Map<String, dynamic>> getLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'isLoggedIn': prefs.getBool('isLoggedIn') ?? false,
      'useLocalAuth': prefs.getBool('useLocalAuth') ?? false,
      'database': prefs.getString('database') ?? '',
      'url': prefs.getString('url') ?? '',
      'password': prefs.getString('pass') ?? '',
    };
  }

  static const _accountsKey = 'loggedInAccounts';

  /// Saves or updates logged-in account information.
  ///
  /// Ensures uniqueness using user login and adds default image if missing.
  Future<void> saveAccount(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    accounts.removeWhere((a) =>
    a['userLogin'] == account['userLogin'] &&
        a['url'] == account['url'] &&
        a['database'] == account['database']);

    accounts.add(account);

    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  /// Retrieves all stored logged-in accounts.
  ///
  /// Returns:
  /// List of stored account maps.
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);
    if (accountsJson == null) return [];
    final decoded = jsonDecode(accountsJson) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Clears all stored logged-in account entries.
  Future<void> clearAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accountsKey);
  }

  Future<void> removeAccount({
    required String userLogin,
    required String userName,
    required int userId,
    required String url,
    required String database,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();

    accounts.removeWhere((a) =>
    a['userLogin'] == userLogin &&
        a['userName'] == userName &&
        a['userId'] == userId &&
        a['url'] == url &&
        a['database'] == database);

    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }
}
