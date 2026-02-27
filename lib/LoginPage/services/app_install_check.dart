import '../../core/company/session/company_session_manager.dart';

/// Utility class for verifying whether required backend modules are installed.
///
/// Uses company-aware RPC calls via [CompanySessionManager] to check
/// module installation status. Includes fallback connectivity validation
/// when module lookup fails.
class AppInstallCheck {
  /// Checks whether a specific backend module is installed.
  ///
  /// Attempts to verify module installation using module registry lookup.
  /// If module lookup fails, performs a fallback API call to confirm
  /// server connectivity.
  ///
  /// Returns:
  /// • true → Module is installed or server is reachable
  /// • false → Module not installed or server unreachable
  ///
  /// Parameters:
  /// • moduleName → Technical name of the module to verify
  Future<bool> isModuleInstalled(String moduleName) async {
    try {
      final count = await CompanySessionManager.callKwWithCompany({
        'model': 'ir.module.module',
        'method': 'search_count',
        'args': [
          [
            ['name', '=', moduleName],
            ['state', '=', 'installed']
          ]
        ],
        'kwargs': {}
      });
      return (count ?? 0) > 0;
    } catch (_) {
      try {
        await CompanySessionManager.callKwWithCompany({
          'model': 'account.move',
          'method': 'search_count',
          'args': [[]],
          'kwargs': {'limit': 1}
        });
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Validates whether mandatory application modules are installed.
  ///
  /// Currently verifies installation of:
  /// • Manufacturing module (mrp)
  ///
  /// Returns:
  /// • true → Required modules available
  /// • false → One or more required modules missing
  Future<bool> checkRequiredModules() async {
    return await isModuleInstalled('mrp');
  }
}
