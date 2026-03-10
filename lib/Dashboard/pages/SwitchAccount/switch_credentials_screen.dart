import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_manufacturing_app/Dashboard/pages/SwitchAccount/server_url_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../LoginPage/models/session_model.dart';
import '../../../LoginPage/pages/totp_page.dart';
import '../../../LoginPage/services/app_install_check.dart';
import '../../../LoginPage/services/storage_service.dart';
import '../../../core/company/services/connectivity_service.dart';
import '../../../core/company/session/company_session_manager.dart';
import '../../../core/providers/motion_provider.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../globals.dart';
import '../../services/app_bootstrapper.dart';
import '../dashboard_mo.dart';

/// Screen where the user enters username and password to authenticate with the Odoo server.
///
/// This screen is part of the account switching / multi-account flow.
/// It handles:
/// - Credential input with validation
/// - Login via CompanySessionManager
/// - Saving account details to persistent storage
/// - 2FA redirection (TOTP) when required
/// - Required module check (Manufacturing)
/// - Cleanup & redirect to login if critical modules are missing
/// - Background service management
/// - History persistence for quick re-login
class SwitchCredentialsScreen extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String protocol;
  final String urlInput;
  final SessionModel session;

  const SwitchCredentialsScreen({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.protocol,
    required this.urlInput,
    required this.session,
  });

  @override
  State<SwitchCredentialsScreen> createState() =>
      _SwitchCredentialsScreenState();
}

class _SwitchCredentialsScreenState extends State<SwitchCredentialsScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;
  String? _previousUrl;
  String? _previousDatabase;
  String? _previousSessionId;
  bool _hadPreviousSession = false;

  @override
  void initState() {
    super.initState();
    _loadPreviousSessionData();
  }

  Future<void> _loadPreviousSessionData() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.session != null &&
        widget.session.sessionId != null &&
        widget.session.sessionId!.isNotEmpty) {
      _hadPreviousSession = true;
      _previousUrl = prefs.getString('url');
      _previousDatabase = prefs.getString('database');
      _previousSessionId = widget.session.sessionId;
    }
  }

  /// Saves the server + credentials to history (most recent first, max 10 entries)
  Future<void> _saveUrlHistoryWithProtocol(
    String protocol,
    String url,
    String database,
    String username,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];

    String finalProtocol = protocol;
    String finalUrl = url.trim();

    // Normalize URL format
    if (finalUrl.startsWith('https://')) {
      finalProtocol = 'https://';
      finalUrl = finalUrl.replaceFirst('https://', '');
    } else if (finalUrl.startsWith('http://')) {
      finalProtocol = 'http://';
      finalUrl = finalUrl.replaceFirst('http://', '');
    }

    final entry = jsonEncode({
      'protocol': finalProtocol,
      'url': finalUrl,
      'db': database,
      'username': username,
    });

    // Remove duplicate entry for this server
    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });

    history.insert(0, entry);
    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  /// Attempts to log in, save session/account, check modules, and navigate accordingly.
  Future<void> _addAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Normalize URL
      String finalUrl = widget.serverUrl.trim();
      String finalProtocol = widget.protocol;

      if (finalUrl.startsWith('https://')) {
        finalProtocol = 'https://';
        finalUrl = finalUrl.replaceFirst('https://', '');
      } else if (finalUrl.startsWith('http://')) {
        finalProtocol = 'http://';
        finalUrl = finalUrl.replaceFirst('http://', '');
      }
      final url = '$finalProtocol$finalUrl';

      // Perform login
      final success = await CompanySessionManager.loginAndSaveSession(
        serverUrl: url,
        database: widget.database,
        userLogin: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!success) throw Exception("Authentication failed.");

      final session = await CompanySessionManager.getCurrentSession();

      // Save account details
      final storageService = StorageService();
      await storageService.saveAccount({
        'userName': session?.userName,
        'userLogin': session?.userLogin,
        'userId': session?.userId,
        'sessionId': session?.sessionId,
        'serverVersion': session?.serverVersion,
        'userLang': session?.userLang,
        'partnerId': session?.partnerId,
        'userTimezone': session?.userTimezone,
        'companyId': session?.companyId,
        'companyName': session?.companyName,
        'isSystem': session?.isSystem,
        'url': url,
        'database': widget.database,
        'image': '',
      });

      // Remember last username
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastUsername', _usernameController.text.trim());

      // Update history
      await _saveUrlHistoryWithProtocol(
        widget.protocol,
        finalUrl,
        widget.database,
        _usernameController.text.trim(),
      );

      if (context.mounted) {
        // Check required modules
        final checker = AppInstallCheck();
        final isInstalled = await checker.checkRequiredModules();

        final motionProvider = Provider.of<MotionProvider>(
          context,
          listen: false,
        );
        if (!isInstalled) {
          await prefs.remove('lastUsername');
          await storageService.removeAccount(
            userLogin: session?.userLogin ?? '',
            userName: session?.userName ?? '',
            userId: session?.userId ?? 0,
            url: url,
            database: widget.database,
          );

          await SecureStorageService().deletePassword(
            url: url,
            database: widget.database,
            username: session?.userLogin ?? '',
          );
          if (_hadPreviousSession &&
              _previousUrl != null &&
              _previousDatabase != null) {
            await prefs.setString('url', _previousUrl!);
            await prefs.setString('database', _previousDatabase!);
            await prefs.setString('selectedDatabase', _previousDatabase!);
            await prefs.setString('sessionId', _previousSessionId!);
            await prefs.setString('userName', widget.session.userName!);
            await prefs.setString('userLogin', widget.session.userLogin!);
            await prefs.setInt('userId', widget.session.userId!);
            await prefs.setString(
                'serverVersion', widget.session.serverVersion!);
            await prefs.setString('userLang', widget.session.userLang!);
            await prefs.setInt('partnerId', widget.session.partnerId!);
            await prefs.setString('userTimezone', widget.session.userTimezone!);
            await prefs.setInt('companyId', widget.session.companyId!);
            await prefs.setString('company_name', widget.session.companyName!);
            await prefs.setBool('isSystem', widget.session.isSystem);
            await prefs.setInt('version', widget.session.version!);
            await prefs.setStringList(
              'allowed_company_ids',
              widget.session.allowedCompanyIds
                  .map((e) => e.toString())
                  .toList(),
            );

            await CompanySessionManager.clearSessionCache();
            await CompanySessionManager.forceRefreshFromPrefs();
            ConnectivityService.instance.setCurrentServerUrl(_previousUrl!);

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServerUrlScreen(
                    serverUrl: _previousUrl!,
                    database: _previousDatabase!,
                    session: widget.session
                ),
              ),
            );
            if (context.mounted) {
              showModuleMissingDialog(context);
            }
            return;
          }
        } else {
          // Success path: bootstrap and go to dashboard
          AppBootstrapper.reloadAppBlocs(context);
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const DashboardMoPage(),
              transitionDuration: motionProvider.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              reverseTransitionDuration: motionProvider.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    if (motionProvider.reduceMotion) return child;
                    return FadeTransition(opacity: animation, child: child);
                  },
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      // Handle 2FA requirement
      if (errorStr.contains('two factor') ||
          errorStr.contains('2fa') ||
          errorStr.contains('null')) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TotpPage(
                protocol: widget.protocol,
                serverUrl: widget.serverUrl,
                database: widget.database,
                username: _usernameController.text.trim(),
                password: _passwordController.text.trim(),
              ),
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _errorMessage = _mapError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void showModuleMissingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        title: Row(
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              color: AppStyle.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Module Missing',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.black,
              ),
            ),
          ],
        ),
        content: Text(
          'The required "Manufacturing" module is not installed. Please contact your administrator to enable it.',
          style: GoogleFonts.manrope(
            fontSize: 15,
            color: Colors.black87,
            height: 1.5,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Back to Add Account',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(seconds: 1));
    } else {}
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                image: DecorationImage(
                  image: const AssetImage("assets/background.png"),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? Colors.black.withOpacity(1)
                        : Colors.white.withOpacity(1),
                    BlendMode.dstATop,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isLoading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                borderRadius: BorderRadius.circular(32),
                                child: Container(
                                  height: 64,
                                  width: 64,
                                  alignment: Alignment.center,
                                  child: Icon(
                                    HugeIcons.strokeRoundedArrowLeft01,
                                    color: _isLoading
                                        ? Colors.white54
                                        : Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/manufacturing-icon.png',
                                  fit: BoxFit.fitWidth,
                                  height: 30,
                                  width: 30,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.precision_manufacturing,
                                      color: Color(0xFFC03355),
                                      size: 20,
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'mobo manufacturing',
                                  style: TextStyle(
                                    fontFamily: 'Yaro',
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white,
                                    fontSize: 24,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      const SizedBox(height: 45),
                      Align(
                        alignment: Alignment.center,
                        child: Text(
                          "Add Account",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 25,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your credentials to continue',
                        style: GoogleFonts.manrope(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputField(
                              controller: _usernameController,
                              label: "Username",
                              icon: HugeIcons.strokeRoundedUser03,
                            ),
                            const SizedBox(height: 20),
                            _buildInputField(
                              controller: _passwordController,
                              label: "Password",
                              obscure: true,
                              isPasswordField: true,
                              icon: HugeIcons.strokeRoundedSquareLockPassword,
                            ),
                          ],
                        ),
                      ),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Adding',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    LoadingAnimationWidget.staggeredDotsWave(
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Add Account',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    IconData? icon,
    bool isPasswordField = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPasswordField ? !_isPasswordVisible : obscure,
      validator: (value) {
        if (value == null || value.isEmpty) return '$label is required';
        return null;
      },
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withOpacity(0.4),
        ),
        prefixIcon: icon != null ? Icon(icon, color: Colors.black26) : null,
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: _isPasswordVisible ? Colors.black26 : Colors.black54,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              )
            : null,
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
