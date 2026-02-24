import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/company/session/company_session_manager.dart';
import '../models/profile.dart';

/// Service class responsible for handling user profile related API operations.
///
/// This includes:
/// - Initializing the Odoo client session
/// - Fetching user profile data
/// - Updating user profile and address
/// - Fetching country and state master data
class ProfileService {
  OdooClient? _client;
  int? userId;
  int? companyId;
  String url = '';

  /// Initializes the Odoo client using the stored company session.
  ///
  /// Throws an exception if no active session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads the logged-in user's profile details from the server.
  ///
  /// Determines the correct mobile field based on server version.
  ///
  /// Returns:
  /// - List of [Profile] objects if successful
  /// - Empty list if any error occurs
  Future<List<Profile>> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      if (_client == null) {
        await initializeClient();
      }
      int version = prefs.getInt('version') ?? 0;
      String mobile;
      if (version < 18) {
        mobile = 'mobile';
      } else {
        mobile = 'mobile_phone';
      }
      final details = [
        'id',
        'name',
        'phone',
        'email',
        'contact_address',
        'company_id',
        'street',
        'street2',
        'state_id',
        'country_id',
        'image_1920',
        'website',
        'function',
        mobile,
      ];
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', userId],
          ],
        ],
        'kwargs': {'fields': details},
      });

      final profileItems = response is List ? response : [];
      return profileItems.map((item) => Profile.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Updates the user profile details.
  ///
  /// Parameters:
  /// - [data]: Map containing user profile fields to update.
  ///
  /// Returns:
  /// - true if update is successful
  /// - false if update fails
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          data,
        ],
        'kwargs': {},
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }

  /// Updates the user address details.
  ///
  /// Parameters:
  /// - [data]: Map containing address fields to update.
  ///
  /// Returns:
  /// - true if update is successful
  /// - false if update fails
  Future<bool> updateUserAddress(Map<String, dynamic> data) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'write',
        'args': [
          [userId],
          data,
        ],
        'kwargs': {},
      });
      return result == true;
    } catch (e) {
      return false;
    }
  }


  /// Fetches the list of countries from the server.
  ///
  /// Returns:
  /// - List of country maps containing id and name
  /// - Empty list if any error occurs
  Future<List<Map<String, dynamic>>> fetchCountries() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.country',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Fetches the list of states from the server.
  ///
  /// Returns:
  /// - List of state maps containing id and name
  /// - Empty list if any error occurs
  Future<List<Map<String, dynamic>>> fetchStates() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'res.country.state',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
