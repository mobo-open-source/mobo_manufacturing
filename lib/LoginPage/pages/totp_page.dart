import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce/hive.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_manufacturing_app/Dashboard/pages/dashboard_mo.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Dashboard/services/app_bootstrapper.dart';
import '../../MO/pages/MoList/service/hive/models.dart';
import '../../core/company/session/company_session_manager.dart';
import '../../core/providers/motion_provider.dart';
import '../../core/security/secure_storage_service.dart';
import '../../globals.dart';
import '../services/app_install_check.dart';
import '../services/common_storage_service.dart';
import '../services/storage_service.dart';

/// Two-Factor Authentication (TOTP) verification screen.
///
/// Receives login credentials and server details from previous login step.
/// Handles hidden web login flow, TOTP verification, session extraction,
/// module validation, and navigation to dashboard on success.
class TotpPage extends StatefulWidget {
  final String serverUrl;
  final String database;
  final String username;
  final String password;
  final String protocol;

  const TotpPage({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.username,
    required this.password,
    required this.protocol,
  });

  @override
  State<TotpPage> createState() => _TotpPageState();
}

/// State class for [TotpPage].
///
/// Manages:
/// • Hidden WebView login automation
/// • TOTP submission and validation
/// • Session cookie extraction and persistence
/// • Module installation verification
/// • Local storage and session cleanup handling
/// • Navigation after authentication
class _TotpPageState extends State<TotpPage> {
  InAppWebViewController? _webController;
  final _totpController = TextEditingController();
  String? _error;
  bool _loading = true;
  bool _verifying = false;
  bool _isButtonEnabled = false;
  final _formKey = GlobalKey<FormState>();
  bool _credentialsInjected = false;
  String? sessionId;
  final CommonStorageService _commonStorageService = CommonStorageService();

  /// Builds the TOTP verification screen UI.
  ///
  /// Includes:
  /// • Background styling
  /// • Hidden WebView for session automation
  /// • TOTP input form
  /// • Loading overlay during authentication flow
  /// • Back navigation control
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage('assets/background.png'),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withOpacity(1)
                          : Colors.white.withOpacity(1),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    '${widget.serverUrl}/web/login?db=${widget.database}',
                  ),
                ),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    javaScriptEnabled: true,
                    cacheEnabled: false,
                    clearCache: true,
                    userAgent:
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                        "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
                  ),
                  android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                    allowContentAccess: true,
                    allowFileAccess: true,
                    mixedContentMode:
                        AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                    forceDark: AndroidForceDark.FORCE_DARK_AUTO,
                    disableDefaultErrorPage: true,
                  ),
                ),
                onWebViewCreated: (controller) {
                  _webController = controller;
                },
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                      return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED,
                      );
                    },

                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  return NavigationActionPolicy.ALLOW;
                },

                onLoadError: (controller, url, code, message) {},

                onReceivedError: (controller, request, errorResponse) {},
                onLoadStop: (controller, url) async {
                  final urlStr = url?.toString() ?? '';

                  if (urlStr.contains('/web/database/selector') ||
                      urlStr.contains('/web/database/manager')) {
                    await _handleDatabaseSelector();
                    return;
                  }

                  if (urlStr.contains('/web/login') && !_credentialsInjected) {
                    await Future.delayed(const Duration(milliseconds: 800));
                    await _injectCredentials();
                    return;
                  }

                  if (urlStr.contains('/web/login/totp') ||
                      urlStr.contains('totp_token')) {
                    if (mounted) {
                      setState(() {
                        _loading = false;
                      });
                    }
                    await Future.delayed(const Duration(milliseconds: 600));
                    await _focusTotpField();
                    return;
                  }

                  if ((urlStr.contains('/web') ||
                          urlStr.contains('/odoo/discuss') ||
                          urlStr.contains('/odoo') ||
                          urlStr.contains('/odoo/apps') ||
                          urlStr.contains('/website')) &&
                      !urlStr.contains('/login') &&
                      !urlStr.contains('/totp')) {
                    await _extractAndSaveSession();
                  }
                },
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: IgnorePointer(
                ignoring: _loading,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: Icon(
                        HugeIcons.strokeRoundedArrowLeft01,
                        color: _loading ? Colors.white54 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildForm(),
              ],
            ),
          ),

          if (_loading)
            Container(
              color: isDark ? Colors.black54 : Colors.white70,
              child: Center(
                child: LoadingAnimationWidget.fourRotatingDots(
                  color: Theme.of(context).colorScheme.primary,
                  size: 60,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Shows dialog when required backend modules are missing.
  ///
  /// Informs user that Manufacturing module is not installed
  /// and provides navigation back to login screen.
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
                'Back to Login',
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

  /// Validates and submits TOTP code through injected WebView JavaScript.
  ///
  /// Handles:
  /// • TOTP format validation
  /// • Form submission via DOM scripting
  /// • Login success detection via DOM and cookies
  /// • Session persistence and local storage updates
  /// • Module installation verification
  /// • Navigation to dashboard or login fallback
  Future<void> _submitTotp() async {
    if (_verifying || _webController == null) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    final totp = _totpController.text.trim();
    if (totp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(totp)) {
      setState(() {
        _error = 'Please enter a valid 6-digit code';
        _verifying = false;
      });
      return;
    }

    try {
      await _webController!.evaluateJavascript(
        source:
            """
  (function() {
    let input = document.querySelector(
      'input[name="totp_token"], input[autocomplete="one-time-code"], input[type="text"][maxlength="6"], input[type="number"][maxlength="6"]'
    );
    if (!input) return "totp_input_not_found";
    
    // Set value and dispatch full input events
    input.focus();
    input.value = '$totp';
    ['input', 'change', 'keydown', 'keyup', 'keypress'].forEach(eventType => {
      input.dispatchEvent(new KeyboardEvent(eventType, {key: 'Enter', bubbles: true, cancelable: true}));
    });
    
    // Handle trust device if present
    const trustCheckbox = document.querySelector('input[name="trust_device"], input[type="checkbox"], [name="trust"]');
    if (trustCheckbox && !trustCheckbox.checked) {
      trustCheckbox.checked = true;
      trustCheckbox.dispatchEvent(new Event('change', {bubbles: true}));
    }
    
    // Submit form
    const form = input.closest('form') || document.querySelector('form[action*="/web/login"]');
    if (form) {
      const btn = form.querySelector('button[type="submit"], button.btn-primary, button[name="submit"], button.btn-block');
      if (btn) {
        btn.click();
      } else {
        form.submit();  // Fallback to native submit
      }
      return "totp_submitted";
    }
    return "form_not_found";
  })();
  """,
      );

      await Future.delayed(const Duration(seconds: 2));

      for (int i = 0; i < 20; i++) {
        final isLoggedIn = await _webController!.evaluateJavascript(
          source: """
    (function() {
      const userMenu = document.querySelector('.o_user_menu, .oe_topbar_avatar, .o_apps_switcher, [data-menu="account"]');
      const webClient = document.querySelector('.o_web_client, .o_action_manager');
      const error = document.querySelector('.alert-danger, .o_error_dialog');
      if (userMenu || webClient) return true;
      if (error) return 'error';
      return false;
    })();
    """,
        );
        if (isLoggedIn == 'error') {
          setState(
            () => _error = "Invalid code or login failed. Please try again.",
          );
          return;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await Future.delayed(const Duration(seconds: 4));

      final currentUrl = await _webController!.getUrl();
      final urlStr = currentUrl?.toString() ?? '';

      final cookies = await CookieManager.instance().getCookies(
        url: currentUrl!,
      );

      final sessionCookie = cookies.firstWhere(
        (c) => c.name == 'session_id',
        orElse: () => Cookie(name: '', value: ''),
      );

      if (sessionCookie.value.isEmpty) {
        setState(() => _error = "Login failed or invalid TOTP.");
        return;
      }

      final domSuccess = await _webController!.evaluateJavascript(
        source: """
      (function() {
        const hasUserMenu = !!document.querySelector('.o_user_menu, .oe_topbar_avatar');
        const hasWebClient = !!document.querySelector('.o_web_client');
        return hasUserMenu || hasWebClient;
      })();
    """,
      );

      if (domSuccess == true ||
          currentUrl.toString().contains('/web?') ||
          currentUrl.toString().contains('/odoo/discuss?') ||
          currentUrl.toString().contains('/odoo') ||
          currentUrl.toString().contains('/odoo/apps?')) {
        await _saveSessionData();
      }

      final isSuccess =
          sessionCookie.value.isNotEmpty &&
          sessionCookie.value.length > 20 &&
          ((urlStr.contains('/web') ||
                  (urlStr.contains('/odoo/discuss')) ||
                  (urlStr.contains('/odoo')) ||
                  (urlStr.contains('/odoo/apps'))) &&
              !urlStr.contains('/login') &&
              !urlStr.contains('/totp'));

      if (!isSuccess) {
        setState(() {
          _error = 'Invalid code or login failed. Please try again.';
        });
        return;
      }

      if (mounted) {
        final checker = AppInstallCheck();
        final isInstalled = await checker.checkRequiredModules();

        if (!isInstalled) {
          final prefs = await SharedPreferences.getInstance();
          List<String> urlHistory = prefs.getStringList('urlHistory') ?? [];
          bool isGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

          await prefs.clear();

          await prefs.setStringList('urlHistory', urlHistory);
          await prefs.setBool('hasSeenGetStarted', isGetStarted);
          await StorageService().clearAccounts();
          await CompanySessionManager.clearSessionCache();
          await SecureStorageService().deleteAllPasswords();
          await stopBackgroundService();

          final productBox = Hive.isBoxOpen('products')
              ? Hive.box<HiveProduct>('products')
              : await Hive.openBox<HiveProduct>('products');
          final bomBox = Hive.isBoxOpen('bom')
              ? Hive.box<HiveBom>('bom')
              : await Hive.openBox<HiveBom>('bom');
          final userBox = Hive.isBoxOpen('users')
              ? Hive.box<HiveUserModel>('users')
              : await Hive.openBox<HiveUserModel>('users');
          final workCenterBox = Hive.isBoxOpen('workCenters')
              ? Hive.box<HiveWorkCenter>('workCenters')
              : await Hive.openBox<HiveWorkCenter>('workCenters');

          await productBox.clear();
          await bomBox.clear();
          await userBox.clear();
          await workCenterBox.clear();

          Navigator.pushNamedAndRemoveUntil(
            context,
            '/login',
            (route) => false,
          );
          if (mounted) {
            showModuleMissingDialog(context);
          }
          return;
        } else {
          final motion = Provider.of<MotionProvider>(context, listen: false);
          AppBootstrapper.reloadAppBlocs(context);
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardMoPage(),
              transitionDuration: motion.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              transitionsBuilder: (_, a, __, c) =>
                  FadeTransition(opacity: a, child: c),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Authentication failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Stops running background service if active.
  ///
  /// Ensures background tasks do not persist after logout/reset flows.
  Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(seconds: 1));
    } else {}
  }

  /// Saves server login history to SharedPreferences.
  ///
  /// Maintains last 10 unique server + protocol entries
  /// along with database and username mapping.
  Future<void> _saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];

    String finalProtocol = protocol;
    String finalUrl = url.trim();

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

    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });

    history.insert(0, entry);
    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  /// Saves authenticated session data to local storage and secure storage.
  ///
  /// Stores:
  /// • Session ID
  /// • User login info
  /// • Server and database details
  /// • Login timestamp
  /// • Account cache for multi-account support
  Future<void> _saveSessionData() async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(widget.serverUrl),
      );

      final sessionCookie = cookies.firstWhere(
        (cookie) => cookie.name == 'session_id',
        orElse: () => Cookie(name: '', value: ''),
      );

      if (sessionCookie.value.isNotEmpty) {
        sessionId = sessionCookie.value;
        final success = await CompanySessionManager.loginAndSaveSession(
          serverUrl: widget.serverUrl,
          database: widget.database,
          userLogin: widget.username.trim(),
          password: widget.password.trim(),
          session_Id: sessionId,
        );
        await _saveUrlHistory(
          protocol: widget.protocol,
          url: widget.serverUrl,
          database: widget.database,
          username: widget.password.trim(),
        );
        if (!success) {
          return;
        }
        final session = await CompanySessionManager.getCurrentSession();
        await _commonStorageService.saveAccount({
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
          'url': widget.serverUrl,
          'database': widget.database,
          'image': '',
        });

        final prefs = await SharedPreferences.getInstance();

        await prefs.remove('logoutAction');

        await prefs.setString('sessionId', sessionId!);
        await prefs.setString('username', widget.username);
        await prefs.setString('url', widget.serverUrl);
        await prefs.setString('database', widget.database);
        await prefs.setBool('logoutAction', false);
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('lastUsername', widget.username.trim());

        await prefs.setInt(
          'loginTimestamp',
          DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        setState(() {
          _error = 'Invalid code or login failed. Please try again.';
        });
        return;
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid code or login failed. Please try again.';
      });
      return;
    }
  }

  /// Injects login credentials into WebView login form using JavaScript.
  ///
  /// Automatically fills:
  /// • Username
  /// • Password
  /// • Database selection
  /// Then submits login form programmatically.
  Future<void> _injectCredentials() async {
    if (_credentialsInjected) return;

    final safeUser = jsonEncode(widget.username);
    final safePass = jsonEncode(widget.password);
    final safeDb = jsonEncode(widget.database);

    final result = await _webController?.evaluateJavascript(
      source:
          """
      (function() {
        const login = document.querySelector('input[name="login"], input[type="email"]');
        const password = document.querySelector('input[name="password"]');
        const db = document.querySelector('input[name="db"], select[name="db"]');
        const form = document.querySelector('form[action*="/web/login"]');

        if (!login || !password || !form) return "missing";

        login.value = $safeUser;
        password.value = $safePass;
        if (db) {
          if (db.tagName === 'INPUT') db.value = $safeDb;
          else db.value = $safeDb;
        }

        const btn = form.querySelector('button[type="submit"]');
        if (btn) btn.click();
        else form.requestSubmit();

        return "submitted";
      })();
    """,
    );

    if (result == "submitted") {
      _credentialsInjected = true;
    }
  }

  /// Focuses and selects TOTP input field inside WebView.
  ///
  /// Improves user experience by ensuring TOTP input is ready.
  Future<void> _focusTotpField() async {
    await _webController?.evaluateJavascript(
      source: """
      const input = document.querySelector('input[name="totp_token"], input[autocomplete="one-time-code"]');
      if (input) {
        input.focus();
        input.select();
      }
    """,
    );
  }

  /// Handles database selection page inside WebView.
  ///
  /// Selects provided database and submits form automatically.
  Future<void> _handleDatabaseSelector() async {
    await _webController?.evaluateJavascript(
      source:
          """
      const select = document.querySelector('select[name="db"]');
      if (select) {
        select.value = '${widget.database}';
        const btn = document.querySelector('button[type="submit"]');
        if (btn) btn.click();
      }
    """,
    );
  }

  /// Extracts session cookie from WebView after successful login.
  ///
  /// Validates session existence and updates error state if missing.
  Future<void> _extractAndSaveSession() async {
    final currentUrl = await _webController?.getUrl();
    if (currentUrl == null) return;

    final cookies = await CookieManager.instance().getCookies(url: currentUrl);
    final sessionCookie = cookies.firstWhere(
      (c) => c.name == 'session_id',
      orElse: () => Cookie(name: 'session_id', value: ''),
    );

    if (sessionCookie.value.isEmpty) {
      setState(() => _error = "Login failed. Please try again.");
      return;
    }
  }

  /// Builds TOTP screen header.
  ///
  /// Displays:
  /// • Two-factor authentication icon
  /// • Title and description
  /// • Server URL information (if available)
  Widget _buildHeader() {
    return Column(
      children: [
        Icon(
          HugeIcons.strokeRoundedTwoFactorAccess,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 24),
        Text(
          'Two-factor Authentication',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'To login, enter below the six-digit authentication code provided by your Authenticator app.',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            color: Colors.white70,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (widget.serverUrl.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Server: ${widget.serverUrl}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  /// Builds TOTP input form and authenticate button.
  ///
  /// Includes:
  /// • TOTP validation
  /// • Error message display
  /// • Button loading state during verification
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            enabled: !_loading || !_verifying,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'TOTP is required';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _isButtonEnabled = value.trim().isNotEmpty;
                _formKey.currentState?.validate();
                if (_error != null) _error = null;
              });
            },
            cursorColor: Colors.black,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
            ),
            decoration: InputDecoration(
              hintText: 'Enter TOTP Code',
              hintStyle: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black.withOpacity(.4),
              ),
              prefixIcon: const Icon(HugeIcons.strokeRoundedSmsCode, size: 20),
              prefixIconColor: MaterialStateColor.resolveWith(
                (states) => states.contains(MaterialState.disabled)
                    ? Colors.black26
                    : Colors.black54,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              errorStyle: const TextStyle(color: Colors.white),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red[900]!, width: 1.0),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _error != null ? 48 : 0,
            child: _error != null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          HugeIcons.strokeRoundedAlertCircle,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.manrope(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_verifying || !_isButtonEnabled) ? null : _submitTotp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _verifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Authenticating',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        LoadingAnimationWidget.staggeredDotsWave(
                          color: Colors.white,
                          size: 28,
                        ),
                      ],
                    )
                  : Text(
                      'Authenticate',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Releases WebView controller and input controllers.
  ///
  /// Prevents memory leaks by disposing active controllers.
  @override
  void dispose() {
    _webController?.dispose();
    _totpController.dispose();
    super.dispose();
  }
}
