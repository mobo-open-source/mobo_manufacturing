import 'package:equatable/equatable.dart';

import '../../models/session_model.dart';

/// Represents the state of the login flow.
///
/// Holds UI-related login data such as:
/// • Loading status
/// • Available database list
/// • Selected database
/// • Error messages
///
/// Extends [Equatable] for efficient state comparison in Bloc.
class LoginState extends Equatable {
  final bool loading;
  final List<String> databases;
  final String? selectedDatabase;
  final String? error;

  /// Creates a [LoginState].
  const LoginState({
    this.loading = false,
    this.databases = const [],
    this.selectedDatabase,
    this.error,
  });

  /// Returns a new [LoginState] with updated values.
  ///
  /// Any parameter left null will retain its previous value,
  /// except [error], which is overwritten directly.
  LoginState copyWith({
    bool? loading,
    List<String>? databases,
    String? selectedDatabase,
    String? error,
  }) {
    return LoginState(
      loading: loading ?? this.loading,
      databases: databases ?? this.databases,
      selectedDatabase: selectedDatabase ?? this.selectedDatabase,
      error: error,
    );
  }

  @override
  List<Object?> get props => [loading, databases, selectedDatabase, error];
}

/// State emitted when login is successful.
///
/// Contains the authenticated user session data.
class LoginSuccess extends LoginState {
  final SessionModel session;

  /// Creates a [LoginSuccess] state.
  const LoginSuccess(this.session);
}
