import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/company/services/session_service.dart';
import '../../services/common_storage_service.dart';
import 'login_event.dart';
import 'login_state.dart';
import '../../services/auth_service.dart';
import '../../services/network_service.dart';
import '../../services/storage_service.dart';

/// Bloc responsible for handling user login flow.
///
/// Responsibilities:
/// • Fetch available databases from server URL
/// • Handle database selection
/// • Perform authentication using session service
/// • Store logged-in account details locally
/// • Handle TOTP / 2FA login scenarios
/// • Map server and network errors to user-friendly messages
class LoginBloc extends Bloc<LoginEvent, LoginState> {
  /// Service used to fetch database list from server.
  final NetworkService networkService;

  /// Service responsible for authentication logic.
  final AuthService authService;

  /// Handles secure storage for login/session data.
  final StorageService storageService;

  /// Handles session creation and retrieval.
  final SessionService sessionService;

  /// Stores multiple account data locally.
  final CommonStorageService _commonStorageService = CommonStorageService();

  LoginBloc(
    this.networkService,
    this.authService,
    this.storageService,
    this.sessionService,
  ) : super(const LoginState()) {
    on<UrlChanged>(_onUrlChanged);
    on<DatabaseSelected>(_onDatabaseSelected);
    on<LoginSubmitted>(_onLoginSubmitted);
  }

  /// Triggered when server URL is changed.
  ///
  /// Normalizes URL format and fetches available databases.
  Future<void> _onUrlChanged(UrlChanged event, Emitter<LoginState> emit) async {
    emit(
      state.copyWith(
        loading: true,
        databases: [],
        selectedDatabase: null,
        error: null,
      ),
    );

    try {
      String normalizedUrl = event.url.trim();

      if (!normalizedUrl.startsWith("http://") &&
          !normalizedUrl.startsWith("https://")) {
        normalizedUrl = "https://$normalizedUrl";
      }

      await Future.delayed(const Duration(seconds: 1));

      final dbList = await networkService.fetchDatabaseList(normalizedUrl);

      emit(
        state.copyWith(
          loading: false,
          databases: dbList,
          selectedDatabase: dbList.isNotEmpty ? dbList.first : null,
        ),
      );
    } catch (e) {
      await Future.delayed(const Duration(milliseconds: 500));

      emit(state.copyWith(loading: false, error: _mapError(e)));
    }
  }

  /// Triggered when a database is selected by user.
  void _onDatabaseSelected(DatabaseSelected event, Emitter<LoginState> emit) {
    emit(state.copyWith(selectedDatabase: event.database));
  }

  /// Triggered when user submits login credentials.
  ///
  /// Handles:
  /// • URL normalization
  /// • Authentication request
  /// • Session retrieval
  /// • Local account storage
  /// • TOTP / 2FA fallback handling
  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(loading: true, error: null));

    try {
      String finalUrl = event.url.trim();
      String finalProtocol = event.protocol;

      if (finalUrl.startsWith('https://')) {
        finalProtocol = 'https://';
        finalUrl = finalUrl.replaceFirst('https://', '');
      } else if (finalUrl.startsWith('http://')) {
        finalProtocol = 'http://';
        finalUrl = finalUrl.replaceFirst('http://', '');
      }

      final url = '$finalProtocol$finalUrl';

      final success = await sessionService.login(
        serverUrl: url,
        database: event.database,
        userLogin: event.username.trim(),
        password: event.password.trim(),
      );
      if (!success) {
        emit(state.copyWith(loading: false, error: 'Authentication failed.'));
        return;
      }

      final session = await sessionService.getSession();

      if (session != null) {
        await StorageService().clearAccounts();
        await _commonStorageService.saveAccount({
          'userName': session.userName,
          'userLogin': session.userLogin,
          'userId': session.userId,
          'sessionId': session.sessionId,
          'serverVersion': session.serverVersion,
          'userLang': session.userLang,
          'partnerId': session.partnerId,
          'userTimezone': session.userTimezone,
          'companyId': session.companyId,
          'companyName': session.companyName,
          'isSystem': session.isSystem,
          'url': url,
          'database': event.database,
          'image': '',
        });

        emit(LoginSuccess(session));
      } else {
        emit(
          state.copyWith(loading: false, error: "Invalid username or password"),
        );
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('two factor') ||
          errorStr.contains('2fa') ||
          errorStr.contains('null')) {
        await StorageService().clearAccounts();
        emit(
          LoginTotpRequired(
            url: event.url,
            database: event.database,
            username: event.username,
            password: event.password,
            protocol: event.protocol,
          ),
        );
        return;
      }
      final message = _mapError(e);
      emit(state.copyWith(loading: false, error: message));
    }
  }

  /// Converts backend or network errors into user-friendly messages.
  String _mapError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('accessdenied') ||
        errorStr.contains('wrong login/password') ||
        errorStr.contains('invalid login') ||
        errorStr.contains('{code: 200') && errorStr.contains('accessdenied')) {
      return 'Incorrect username or password. Please check your login credentials.';
    } else if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') ||
        errorStr.contains('wrong credentials')) {
      return 'Incorrect email or password. Please check your login credentials.';
    } else if (errorStr.contains('user not found') ||
        errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
    } else if (errorStr.contains('database') &&
        errorStr.contains('not found')) {
      return 'Selected database is not available. Please choose a different database.';
    } else if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. The server may be slow or unreachable.';
    } else if (errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access denied. Your account may not have permission to access this database.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    } else if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
      return 'SSL connection failed. Try using HTTP instead of HTTPS.';
    } else if (errorStr.contains('connection refused')) {
      return 'Server is not responding. Please verify the server URL and try again.';
    } else {
      return 'Login failed. Please check your credentials and server settings.';
    }
  }
}

/// State emitted when Two-Factor Authentication (TOTP) is required.
///
/// Stores login details temporarily to continue authentication
/// after TOTP verification.
class LoginTotpRequired extends LoginState {
  final String url;
  final String database;
  final String username;
  final String password;
  final String protocol;

  const LoginTotpRequired({
    required this.url,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
  });
}
