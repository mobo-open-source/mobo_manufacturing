import 'dart:convert';

import 'package:local_auth/local_auth.dart';
import 'package:odoo_rpc/odoo_rpc.dart';
import '../../core/security/self_signed.dart';
import '../models/auth_model.dart';
import '../models/session_model.dart';

/// Handles authentication and session management operations.
///
/// Provides:
/// • Biometric authentication support
/// • Odoo session authentication (password or session reuse)
/// • Session validation and retrieval
/// • Server version parsing for feature compatibility
/// • Company and permission context extraction
///
/// Used by controllers and session managers to establish and validate
/// authenticated user sessions.
class AuthService {
  /// Local device biometric authentication handler.
  ///
  /// Supports fingerprint, face ID, or device credentials
  /// depending on platform capabilities.
  final LocalAuthentication _auth = LocalAuthentication();

  /// Performs biometric authentication using device-supported methods.
  ///
  /// Uses sticky authentication to maintain authentication state
  /// while the app is in the foreground.
  ///
  /// Returns:
  /// • AuthenticationResult.success → Authentication passed
  /// • AuthenticationResult.failure → Authentication rejected
  /// • AuthenticationResult.unavailable → Biometrics not supported
  /// • AuthenticationResult.error → Unexpected authentication error
  Future<AuthenticationResult> authenticateWithBiometrics() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      if (canCheck) {
        final success = await _auth.authenticate(
          localizedReason: 'Authenticate to access the app',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        return success
            ? AuthenticationResult.success
            : AuthenticationResult.failure;
      }
      return AuthenticationResult.unavailable;
    } catch (_) {
      return AuthenticationResult.error;
    } finally {
      await _auth.stopAuthentication();
    }
  }

  /// Extracts the major version number from server version string.
  ///
  /// Example:
  /// • "17.0+e" → 17
  /// • "16.3" → 16
  ///
  /// Returns 0 if parsing fails or version string is invalid.
  int parseMajorVersion(String? serverVersion) {
    if (serverVersion == null || serverVersion.isEmpty) return 0;
    final match = RegExp(r'(\d{1,2})').firstMatch(serverVersion);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  /// Retrieves session metadata from server using existing session ID.
  ///
  /// Calls Odoo session endpoint and returns raw session data.
  ///
  /// Parameters:
  /// • url → Odoo server base URL
  /// • sessionId → Existing session cookie value
  ///
  /// Returns:
  /// Map containing session information such as:
  /// • user id
  /// • username
  /// • language
  /// • timezone
  /// • server version
  Future<Map<String, dynamic>> getSessionInfo(
    String url,
    String sessionId,
  ) async {
    final response = await ioClient.post(
      Uri.parse('$url/web/session/get_session_info'),
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Origin': url,
        'Cookie': 'session_id=$sessionId',
      },
      body: jsonEncode({
        "jsonrpc": "2.0",
        "method": "call",
        "params": {},
        "id": 1,
      }),
    );

    final data = jsonDecode(response.body);
    return Map<String, dynamic>.from(data['result']);
  }

  /// Executes authenticated Odoo RPC call using existing session cookie.
  ///
  /// Used when session is already established and authentication
  /// via password is not required.
  ///
  /// Parameters:
  /// • url → Server base URL
  /// • sessionId → Session cookie value
  /// • payload → Odoo JSON-RPC payload
  ///
  /// Returns:
  /// RPC call result data.
  ///
  /// Throws:
  /// • Server RPC error if response contains error payload.
  Future<dynamic> callKwWithSession({
    required String url,
    required String sessionId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await ioClient.post(
      Uri.parse('$url/web/dataset/call_kw'),
      headers: {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Cookie': 'session_id=$sessionId',
      },
      body: jsonEncode(payload),
    );

    final data = jsonDecode(res.body);
    if (data['error'] != null) throw data['error'];
    return data['result'];
  }

  /// Normalizes company data returned from Odoo RPC responses.
  ///
  /// Supports:
  /// • Many2one list format → [id, name]
  /// • Map format → {id, display_name}
  ///
  /// Returns:
  /// Map containing normalized:
  /// • id → Company ID
  /// • name → Company display name
  Map<String, dynamic>? _parseCompany(dynamic value) {
    if (value == null) return null;

    if (value is List && value.length >= 2) {
      return {'id': value[0], 'name': value[1]};
    }

    if (value is Map) {
      return {
        'id': value['id'],
        'name': value['display_name'] ?? value['name'],
      };
    }
    return null;
  }

  /// Authenticates user with Odoo server and builds application session model.
  ///
  /// Supports two authentication modes:
  /// • Session reuse (sessionId provided)
  /// • Username/password authentication
  ///
  /// Performs:
  /// • Session validation
  /// • User information retrieval
  /// • Company context extraction
  /// • Permission checks (system group)
  /// • Allowed company list retrieval
  /// • Server version compatibility handling
  ///
  /// Parameters:
  /// • url → Odoo server URL
  /// • database → Database name
  /// • username → Login username
  /// • password → Login password
  /// • sessionId → Optional existing session cookie
  ///
  /// Returns:
  /// • SessionModel → Valid authenticated session
  /// • null → Authentication failed or session invalid
  ///
  /// Throws:
  /// • Rethrows underlying network or RPC errors.
  Future<SessionModel?> authenticateOdoo({
    required String url,
    required String database,
    required String username,
    required String password,
    sessionId,
  }) async {
    try {
      final client = OdooClient(url);
      final session;
      int userId = 0;
      if (sessionId != null) {
        final sessionInfo = await getSessionInfo(url, sessionId);

        final int userId = sessionInfo['uid'];
        final String serverVersion = sessionInfo['server_version'];
        final int majorVersion = parseMajorVersion(serverVersion);

        final userData = await callKwWithSession(
          url: url,
          sessionId: sessionId,
          payload: {
            "jsonrpc": "2.0",
            "method": "call",
            "params": {
              "model": "res.users",
              "method": "read",
              "args": [
                [userId],
                ["company_id"],
              ],
              "kwargs": {},
            },
            "id": 1,
          },
        );

        final company = _parseCompany(userData[0]['company_id']);
        bool isSystem = false;
        if (majorVersion >= 18) {
          isSystem =
              await callKwWithSession(
                url: url,
                sessionId: sessionId,
                payload: {
                  "jsonrpc": "2.0",
                  "method": "call",
                  "params": {
                    "model": "res.users",
                    "method": "has_group",
                    "args": [userId, "base.group_system"],
                    "kwargs": {},
                  },
                  "id": 1,
                },
              ) ==
              true;
        } else {
          isSystem =
              await callKwWithSession(
                url: url,
                sessionId: sessionId,
                payload: {
                  "jsonrpc": "2.0",
                  "method": "call",
                  "params": {
                    "model": "res.users",
                    "method": "has_group",
                    "args": ["base.group_system"],
                    "kwargs": {},
                  },
                  "id": 1,
                },
              ) ==
              true;
        }

        List<int> allowedCompanyIds = [];
        if (majorVersion >= 13) {
          final companiesRes = await callKwWithSession(
            url: url,
            sessionId: sessionId,
            payload: {
              "jsonrpc": "2.0",
              "method": "call",
              "params": {
                "model": "res.users",
                "method": "read",
                "args": [
                  [userId],
                  ["company_ids"],
                ],
                "kwargs": {},
              },
              "id": 1,
            },
          );

          if (companiesRes is List && companiesRes.isNotEmpty) {
            allowedCompanyIds =
                (companiesRes[0]['company_ids'] as List?)?.cast<int>() ?? [];
          }
        }

        return SessionModel(
          sessionId: sessionId,
          userId: userId,
          userLogin: sessionInfo['username'],
          userName: sessionInfo['name'],
          serverVersion: serverVersion,
          version: majorVersion,
          userLang: sessionInfo['lang'],
          userTimezone: sessionInfo['tz'],
          partnerId: sessionInfo['partner_id'],
          companyId: company?['id'],
          companyName: company?['name'],
          isSystem: isSystem,
          allowedCompanyIds: allowedCompanyIds,
        );
      } else {
        session = await client.authenticate(database, username, password);
        userId = session.userId;

        if (session != null) {
          final userData = await client.callKw({
            'model': 'res.users',
            'method': 'read',
            'args': [
              [userId],
              ['company_id'],
            ],
            'kwargs': {},
          });
          final int majorVersion = parseMajorVersion(session.serverVersion);

          bool isSystem = false;

          if (majorVersion >= 18) {
            isSystem = await client.callKw({
              'model': 'res.users',
              'method': 'has_group',
              'args': [session.userId, 'base.group_system'],
              'kwargs': {},
            });
          } else {
            isSystem = await client.callKw({
              'model': 'res.users',
              'method': 'has_group',
              'args': ['base.group_system'],
              'kwargs': {},
            });
          }

          List<int> allowedCompanyIds = [];
          if (majorVersion >= 13) {
            final companiesRes = await client.callKw({
              'model': 'res.users',
              'method': 'read',
              'args': [
                [session.userId],
                ['company_ids'],
              ],
              'kwargs': {},
            });
            if (companiesRes is List && companiesRes.isNotEmpty) {
              allowedCompanyIds =
                  (companiesRes[0]['company_ids'] as List?)?.cast<int>() ?? [];
            }
          }
          return SessionModel(
            sessionId: session.id,
            userName: session.userName,
            userLogin: session.userLogin?.toString(),
            userId: session.userId,
            serverVersion: session.serverVersion,
            userLang: session.userLang,
            partnerId: session.partnerId,
            userTimezone: session.userTz,
            companyId: userData.isNotEmpty
                ? userData[0]['company_id'][0]
                : null,
            companyName: userData.isNotEmpty
                ? userData[0]['company_id'][1]
                : null,
            isSystem: isSystem,
            version: majorVersion,
            allowedCompanyIds: allowedCompanyIds,
          );
        }
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
