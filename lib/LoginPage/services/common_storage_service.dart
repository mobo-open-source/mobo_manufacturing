import 'dart:convert';
import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session_model.dart';

/// Service responsible for persisting and retrieving application session
/// and user-related data using local device storage.
///
/// Uses SharedPreferences for lightweight key-value persistence.
///
/// Handles:
/// • Session storage
/// • Login state persistence
/// • User profile caching
/// • Multi-account storage
/// • Map token storage
/// • Selective data clearing while preserving onboarding and URL history
class CommonStorageService {

  /// Stores authenticated session details locally.
  ///
  /// Persists user, company, and server metadata required for restoring
  /// application state without re-authentication.
  ///
  /// Parameters:
  /// • session → Authenticated session model
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

  /// Saves login state and connection configuration.
  ///
  /// Used to restore login context during app startup.
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

  /// Retrieves stored session and login configuration data.
  ///
  /// Returns a map containing user identity, session metadata,
  /// company info, and connection configuration.
  ///
  /// Returns:
  /// • Map<String, dynamic> → Session data with safe default values
  Future<Map<String, dynamic>> getSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getInt('userId') ?? 0,
      'url': prefs.getString('url') ?? '',
      'db': prefs.getString('database') ?? '',
      'sessionId': prefs.getString('sessionId') ?? '',
      'serverVersion': prefs.getString('serverVersion') ?? '',
      'userLang': prefs.getString('userLang') ?? '',
      'companyId': prefs.getInt('companyId') ?? 1,
      'isSystem': prefs.getBool('isSystem') ?? false,
      'partnerId': prefs.getInt('partnerId') ?? 0,
      'userLogin': prefs.getString('userLogin') ?? '',
      'userName': prefs.getString('userName') ?? '',
      'allowedCompanies': prefs.getStringList('allowedCompanies') ?? [],
      'mapToken': prefs.getString('mapToken') ?? '',
    };
  }

  /// Clears all stored session and login-related data.
  ///
  /// Typically used during logout or session invalidation.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Stores map service authentication token locally.
  ///
  /// Parameters:
  /// • token → Map API token string
  Future<void> saveMapToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapToken', token);
  }

  /// Converts stored company JSON strings into Company model objects.
  ///
  /// Parameters:
  /// • companies → List of JSON encoded company strings
  ///
  /// Returns:
  /// • List<Company> → Parsed company model list
  List<Company> parseCompanies(List<String> companies) {
    return companies
        .map((jsonString) => Company.fromJson(jsonDecode(jsonString)))
        .toList();
  }

  /// Saves user profile data locally as JSON.
  ///
  /// Used for quick profile restoration and offline access.
  ///
  /// Parameters:
  /// • user → User profile map data
  Future<void> saveUserProfile(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('user_profile', jsonEncode(user));
  }

  /// Retrieves cached user profile data if available.
  ///
  /// Returns:
  /// • Map<String, dynamic>? → User profile data or null if not found
  Future<Map<String, dynamic>?> getSavedUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_profile');
    if (data != null) {
      return Map<String, dynamic>.from(jsonDecode(data));
    }
    return null;
  }

  static const _accountsKey = 'loggedInAccounts';

  /// Stores or updates logged-in account information.
  ///
  /// Ensures uniqueness based on user login and adds default
  /// image placeholder when missing.
  ///
  /// Parameters:
  /// • account → Account metadata map
  Future<void> saveAccount(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getAccounts();
    accounts.removeWhere((a) => a['userLogin'] == account['userLogin']);
    if (!account.containsKey('image')) {
      account['image'] = '';
    }

    accounts.add(account);

    await prefs.setString(_accountsKey, jsonEncode(accounts));
  }

  /// Retrieves all stored logged-in account entries.
  ///
  /// Returns:
  /// • List<Map<String, dynamic>> → Stored account list
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final accountsJson = prefs.getString(_accountsKey);
    if (accountsJson == null) return [];
    final decoded = jsonDecode(accountsJson) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  /// Clears all local storage while preserving critical onboarding data.
  ///
  /// Preserves:
  /// • URL history
  /// • Get Started completion state
  ///
  /// Used for full app reset scenarios.
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> urlHistory = prefs.getStringList('urlHistory') ?? [];
    bool hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

    await prefs.clear();
    await prefs.setStringList('urlHistory', urlHistory);
    await prefs.setBool('hasSeenGetStarted', hasSeenGetStarted);
  }
}
