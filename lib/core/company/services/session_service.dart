import '../../../LoginPage/models/session_model.dart';
import '../session/company_session_manager.dart';

/// Service layer for handling session-related operations in the app.
/// Provides methods for user login and retrieving the current saved session.
/// Acts as a wrapper around CompanySessionManager for session management.
class SessionService {
  Future<bool> login({
    required String serverUrl,
    required String database,
    required String userLogin,
    required String password,
  }) {
    return CompanySessionManager.loginAndSaveSession(
      serverUrl: serverUrl,
      database: database,
      userLogin: userLogin,
      password: password,
    );
  }

  Future<SessionModel?> getSession() {
    return CompanySessionManager.getCurrentSession();
  }
}
