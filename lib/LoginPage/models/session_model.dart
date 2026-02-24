/// Model representing the authenticated user session.
///
/// Stores user, company, and server-related session information
/// returned after successful authentication.
///
/// Used for:
/// • Maintaining logged-in user details
/// • Storing session identifier for API requests
/// • Managing company access and permissions
class SessionModel {
  final String? userName;
  final String? userLogin;
  final int? userId;
  final String sessionId;
  final String? serverVersion;
  final String? userLang;
  final int? partnerId;
  final String? userTimezone;
  final int? companyId;
  final String? companyName;
  final bool isSystem;
  final int? version;
  final List<int> allowedCompanyIds;

  /// Creates a [SessionModel] instance.
  ///
  /// [sessionId] is required as it is used for authenticated requests.
  ///
  /// Defaults:
  /// • [isSystem] → false
  /// • [allowedCompanyIds] → empty list
  SessionModel({
    required this.sessionId,
    this.userName,
    this.userLogin,
    this.userId,
    this.serverVersion,
    this.userLang,
    this.partnerId,
    this.userTimezone,
    this.companyId,
    this.companyName,
    this.isSystem = false,
    this.version,
    this.allowedCompanyIds = const [],
  });
}
