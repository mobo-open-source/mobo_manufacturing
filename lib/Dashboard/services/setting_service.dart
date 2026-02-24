import '../../core/company/session/company_session_manager.dart';

/// Service class responsible for handling application settings related APIs.
///
/// This includes:
/// - Fetching available languages
/// - Fetching available currencies
/// - Fetching available timezones
/// - Updating user language preferences
class SettingService {
  int? userId;
  int? companyId;
  String url = '';

  /// Initializes the client session using stored company session data.
  ///
  /// Throws an exception if no active session exists.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Fetches the list of active languages from the server.
  ///
  /// Returns:
  /// - List of language objects if available
  /// - null if no languages are found or if an error occurs
  Future<List<dynamic>?> fetchLanguage() async {
    try {
      final languageDetails = await CompanySessionManager.callKwWithCompany({
        'model': 'res.lang',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
        ],
        'kwargs': {
          'fields': ['code', 'name', 'iso_code', 'direction'],
          'order': 'name',
        },
      });
      return languageDetails?.isNotEmpty == true ? languageDetails : null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches the list of active currencies from the server.
  ///
  /// Returns:
  /// - List of currency objects if available
  /// - null if no currencies are found or if an error occurs
  Future<List<dynamic>?> fetchCurrency() async {
    try {
      final languageDetails = await CompanySessionManager.callKwWithCompany({
        'model': 'res.currency',
        'method': 'search_read',
        'args': [
          [
            ['active', '=', true],
          ],
          ['name', 'full_name', 'symbol', 'position', 'rounding'],
        ],
        'kwargs': {'order': 'name'},
      });
      return languageDetails?.isNotEmpty == true ? languageDetails : null;
    } catch (e) {
      return null;
    }
  }

  /// Cached list of available timezones.
  List<Map<String, dynamic>> _availableTimezones = [];

  /// Fetches the list of available timezones from the server.
  ///
  /// If server data is unavailable, fallback timezone values are returned.
  ///
  /// Returns:
  /// - List of timezone maps containing code and name
  Future<List<Map<String, dynamic>>> fetchTimezones() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'fields_get',
        'args': [
          ['tz'],
        ],
        'kwargs': {
          'attributes': ['selection', 'string'],
        },
      });

      final tzField = (result != null)
          ? result['tz'] as Map<String, dynamic>?
          : null;
      final selection = tzField != null
          ? tzField['selection'] as List<dynamic>?
          : null;

      List<Map<String, dynamic>> timezones = [];

      if (selection != null && selection.isNotEmpty) {
        timezones = selection.map<Map<String, dynamic>>((item) {
          if (item is List && item.length >= 2) {
            return {'code': item[0].toString(), 'name': item[1].toString()};
          }
          return {'code': item.toString(), 'name': item.toString()};
        }).toList();
      }

      if (timezones.isEmpty) {
        timezones = [
          {'code': 'UTC', 'name': 'UTC'},
          {'code': 'Europe/Brussels', 'name': 'Europe/Brussels'},
          {'code': 'Asia/Kolkata', 'name': 'Asia/Kolkata'},
          {'code': 'America/New_York', 'name': 'America/New_York'},
        ];
      }

      _availableTimezones = timezones;

      return timezones;
    } catch (e) {
      _availableTimezones = [
        {'code': 'UTC', 'name': 'UTC'},
        {'code': 'America/New_York', 'name': 'Eastern Time (US & Canada)'},
        {'code': 'America/Chicago', 'name': 'Central Time (US & Canada)'},
        {'code': 'America/Denver', 'name': 'Mountain Time (US & Canada)'},
        {'code': 'America/Los_Angeles', 'name': 'Pacific Time (US & Canada)'},
        {'code': 'Europe/London', 'name': 'London'},
        {'code': 'Europe/Paris', 'name': 'Paris'},
        {'code': 'Europe/Berlin', 'name': 'Berlin'},
        {'code': 'Asia/Tokyo', 'name': 'Tokyo'},
        {'code': 'Asia/Shanghai', 'name': 'Shanghai'},
        {'code': 'Asia/Kolkata', 'name': 'Mumbai, Kolkata, New Delhi'},
        {'code': 'Asia/Dubai', 'name': 'Dubai'},
        {'code': 'Australia/Sydney', 'name': 'Sydney'},
      ];
      return _availableTimezones;
    } finally {}
  }

  /// Updates the user's language preference.
  ///
  /// Parameters:
  /// - [id]: User ID
  /// - [updatedValue]: Map containing updated language values
  Future<void> updateLanguage(int id, updatedValue) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [id, updatedValue],
        'kwargs': {},
      });
    } catch (e) {
      return;
    }
  }
}
