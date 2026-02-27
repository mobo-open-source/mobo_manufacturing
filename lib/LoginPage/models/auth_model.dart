/// Represents the result of a biometric authentication attempt.
enum AuthenticationResult { success, failure, error, unavailable }

/// Model representing authentication and login state of the user.
///
/// Used to:
/// • Track login session status
/// • Determine whether biometric authentication is required
/// • Store the latest authentication result (optional)
class AuthModel {
  final bool isLoggedIn;
  final bool useLocalAuth;
  final AuthenticationResult? authResult;

  /// Creates an [AuthModel].
  ///
  /// Defaults:
  /// • [isLoggedIn] → false
  /// • [useLocalAuth] → false
  /// • [authResult] → null
  AuthModel({
    this.isLoggedIn = false,
    this.useLocalAuth = false,
    this.authResult,
  });

  /// Creates a new [AuthModel] by overriding selected fields.
  ///
  /// Useful for immutable state updates.
  AuthModel copyWith({
    bool? isLoggedIn,
    bool? useLocalAuth,
    AuthenticationResult? authResult,
  }) {
    return AuthModel(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      useLocalAuth: useLocalAuth ?? this.useLocalAuth,
      authResult: authResult ?? this.authResult,
    );
  }
}
