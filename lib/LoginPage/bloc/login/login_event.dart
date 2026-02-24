import 'package:equatable/equatable.dart';

/// Base class for all login-related events.
///
/// Extends [Equatable] to allow value comparison,
/// which helps Bloc efficiently detect state changes.
abstract class LoginEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Event triggered when the server URL input changes.
///
/// Used to validate the URL and fetch available databases.
class UrlChanged extends LoginEvent {
  /// The server URL entered by the user.
  final String url;

  /// Creates a [UrlChanged] event.
  UrlChanged(this.url);

  @override
  List<Object?> get props => [url];
}

/// Event triggered when the user selects a database.
///
/// Updates the selected database in the login state.
class DatabaseSelected extends LoginEvent {
  final String database;

  /// Creates a [DatabaseSelected] event.
  DatabaseSelected(this.database);

  @override
  List<Object?> get props => [database];
}

/// Event triggered when the user submits the login form.
///
/// Contains all required login credentials and server details.
class LoginSubmitted extends LoginEvent {
  final String url;
  final String database;
  final String username;
  final String password;
  final String protocol;

  /// Creates a [LoginSubmitted] event.
  LoginSubmitted({
    required this.url,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
  });

  @override
  List<Object?> get props => [url, database, username, password, protocol];
}
