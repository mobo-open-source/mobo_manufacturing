import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce/hive.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mobo_manufacturing_app/LoginPage/pages/reset_password.dart';
import 'package:mobo_manufacturing_app/LoginPage/pages/totp_page.dart';
import 'package:mobo_manufacturing_app/core/company/services/session_service.dart';
import '../../Dashboard/services/app_bootstrapper.dart';
import '../../MO/pages/MoList/service/hive/models.dart';
import '../../core/company/session/company_session_manager.dart';
import '../../core/providers/motion_provider.dart';
import '../../core/security/secure_storage_service.dart';
import '../../globals.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Dashboard/pages/dashboard_mo.dart';
import '../../shared/widgets/snackbar.dart';
import '../bloc/login/login_bloc.dart';
import '../bloc/login/login_event.dart';
import '../bloc/login/login_state.dart';
import '../services/app_install_check.dart';
import '../services/auth_service.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';

/// Screen for entering user login credentials.
///
/// This page handles:
/// • Username and password input
/// • Biometric authentication (if enabled)
/// • Login submission using [LoginBloc]
/// • TOTP navigation when two-factor authentication is required
/// • Manufacturing module validation after login
/// • Session cleanup if required module is missing
/// • URL history storage for quick login reuse
///
/// Integrates with:
/// • [LoginBloc] → Authentication state management
/// • [SessionService] → Session handling
/// • [AuthService] → Biometric authentication
/// • [StorageService] → Local login/session persistence
/// • [MotionProvider] → Reduced motion accessibility
class CredentialsPage extends StatefulWidget {
  final String protocol;
  final String url;
  final String database;

  /// Creates a [CredentialsPage].
  ///
  /// Requires server connection details.
  const CredentialsPage({
    super.key,
    required this.protocol,
    required this.url,
    required this.database,
  });

  @override
  State<CredentialsPage> createState() => _CredentialsPageState();
}

/// State for [CredentialsPage].
///
/// Manages:
/// • Form validation
/// • Loading state
/// • Biometric authentication
/// • Login submission flow
/// • URL history persistence
/// • Background service control
class _CredentialsPageState extends State<CredentialsPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _biometricEnabled = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
  }

  /// Loads biometric preference from shared preferences.
  ///
  /// Determines whether biometric authentication
  /// should be required during login.
  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    });
  }

  /// Performs biometric authentication using device hardware.
  ///
  /// Supports:
  /// • Fingerprint
  /// • Face ID (iOS)
  ///
  /// Returns:
  /// • true → Authentication successful
  /// • false → Authentication failed or unavailable
  Future<bool> _authenticateWithBiometrics() async {
    try {
      bool canAuthenticate =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuthenticate) {
        if (mounted) {
          CustomSnackbar.showError(
            context,
            'Biometric authentication is not available on this device',
          );
        }
        return false;
      }

      List<BiometricType> availableBiometrics = await _localAuth
          .getAvailableBiometrics();
      String biometricType = 'biometric';
      if (Platform.isIOS && availableBiometrics.contains(BiometricType.face)) {
        biometricType = 'Face ID';
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        biometricType = 'Touch ID';
      }

      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate with $biometricType to log in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (!authenticated && mounted) {
        CustomSnackbar.showError(
          context,
          'Failed to authenticate with $biometricType',
        );
      }
      return authenticated;
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(
          context,
          'Error during biometric authentication, please try again later',
        );
      }
      return false;
    }
  }

  /// Displays dialog when required Manufacturing module is missing.
  ///
  /// Prevents user from entering dashboard if module
  /// dependency is not installed on server.
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

  /// Saves login server history including protocol and username.
  ///
  /// Maintains last 10 login entries.
  /// Removes duplicate entries automatically.
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

  /// Builds the credentials login UI and wires authentication state handling.
  ///
  /// Responsibilities:
  /// • Applies theme-based background styling (dark/light mode)
  /// • Initializes [LoginBloc] with required services
  /// • Handles navigation based on login states:
  ///   - Navigates to TOTP screen when 2FA is required
  ///   - Navigates to Dashboard on successful login
  ///   - Shows error messages when login fails
  ///
  /// UI Features:
  /// • Manufacturing branded background layout
  /// • Username and password input fields
  /// • Password visibility toggle
  /// • Forgot password navigation
  /// • Biometric authentication before login (if enabled)
  /// • Animated transitions respecting reduced motion accessibility
  ///
  /// Post Login Validation:
  /// • Verifies required Manufacturing module installation
  /// • Clears session, storage, Hive cache, and background services if missing
  /// • Preserves URL history and onboarding state during forced cleanup
  ///
  /// State Handling:
  /// • Uses [BlocConsumer] to separate UI rendering and side effects
  /// • Shows loading indicator while login request is processing
  ///
  /// Returns:
  /// • Fully configured credentials login screen widget tree
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    String baseUrl = widget.url.trim();

    if (baseUrl.startsWith("http://") || baseUrl.startsWith("https://")) {
      baseUrl = baseUrl.replaceFirst(RegExp(r'^https?://'), '');
    }
    return BlocProvider(
      create: (_) => LoginBloc(
        NetworkService(),
        AuthService(),
        StorageService(),
        SessionService(),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: AssetImage("assets/background.png"),
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
                                      return Icon(
                                        Icons.precision_manufacturing,
                                        color: Color(0xFFC03355),
                                        size: 20,
                                      );
                                    },
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'mobo manufacturing',
                                    style: const TextStyle(
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
                    child: BlocConsumer<LoginBloc, LoginState>(
                      listener: (context, state) async {
                        if (state is LoginTotpRequired) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TotpPage(
                                serverUrl: state.url,
                                database: state.database,
                                username: state.username,
                                password: state.password,
                                protocol: state.protocol,
                              ),
                            ),
                          );
                        }
                        if (state is LoginSuccess) {
                          setState(() {
                            _isLoading = false;
                          });
                          final checker = AppInstallCheck();
                          final isInstalled = await checker
                              .checkRequiredModules();

                          if (!isInstalled) {
                            final prefs = await SharedPreferences.getInstance();
                            List<String> urlHistory =
                                prefs.getStringList('urlHistory') ?? [];
                            bool isGetStarted =
                                prefs.getBool('hasSeenGetStarted') ?? false;

                            await prefs.clear();

                            await prefs.setStringList('urlHistory', urlHistory);
                            await prefs.setBool(
                              'hasSeenGetStarted',
                              isGetStarted,
                            );
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
                                : await Hive.openBox<HiveWorkCenter>(
                                    'workCenters',
                                  );

                            await productBox.clear();
                            await bomBox.clear();
                            await userBox.clear();
                            await workCenterBox.clear();

                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (route) => false,
                            );
                            if (context.mounted) {
                              showModuleMissingDialog(context);
                            }
                            return;
                          } else {
                            AppBootstrapper.reloadAppBlocs(context);
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        const DashboardMoPage(),
                                transitionDuration: motionProvider.reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                reverseTransitionDuration:
                                    motionProvider.reduceMotion
                                    ? Duration.zero
                                    : const Duration(milliseconds: 300),
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) {
                                      if (motionProvider.reduceMotion) {
                                        return child;
                                      }
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                              ),
                            );
                          }
                        }
                        if (state.error != null && state.error!.isNotEmpty) {
                          setState(() => _isLoading = false);
                        }
                      },
                      builder: (context, state) {
                        return Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Sign In',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 32,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Enter your credentials to continue',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 30),
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
                                icon: HugeIcons.strokeRoundedSquareLockPassword,
                                isPasswordField: true,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      PageRouteBuilder(
                                        pageBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                            ) => ResetPasswordScreen(
                                              url: widget.protocol + widget.url,
                                              database: widget.database,
                                            ),
                                        transitionDuration:
                                            motionProvider.reduceMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 300),
                                        reverseTransitionDuration:
                                            motionProvider.reduceMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 300),
                                        transitionsBuilder:
                                            (
                                              context,
                                              animation,
                                              secondaryAnimation,
                                              child,
                                            ) {
                                              if (motionProvider.reduceMotion) {
                                                return child;
                                              }
                                              return FadeTransition(
                                                opacity: animation,
                                                child: child,
                                              );
                                            },
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              if (state.error != null) ...[
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    state.error!,
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    setState(() {
                                      _isLoading = true;
                                    });
                                    if (_formKey.currentState!.validate()) {
                                      if (_biometricEnabled) {
                                        bool authenticated =
                                            await _authenticateWithBiometrics();
                                        if (!authenticated) {
                                          return;
                                        }
                                      }

                                      String url = widget.url.trim();
                                      if (url.startsWith('https://')) {
                                        url = url.replaceFirst('https://', '');
                                      } else if (url.startsWith('http://')) {
                                        url = url.replaceFirst('http://', '');
                                      }
                                      final fullUrl = widget.protocol + url;
                                      await _saveUrlHistoryWithProtocol(
                                        widget.protocol,
                                        url,
                                        widget.database,
                                        _usernameController.text.trim(),
                                      );

                                      context.read<LoginBloc>().add(
                                        LoginSubmitted(
                                          url: fullUrl,
                                          database: widget.database,
                                          username: _usernameController.text
                                              .trim(),
                                          password: _passwordController.text
                                              .trim(),
                                          protocol: widget.protocol,
                                        ),
                                      );
                                    } else {
                                      setState(() {
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Signing',
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
                                      : Text(
                                          "Sign In",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stops running background service if active.
  ///
  /// Used during logout or invalid module state cleanup.
  Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(seconds: 1));
    } else {}
  }

  /// Builds styled input field used for login form.
  ///
  /// Supports:
  /// • Password visibility toggle
  /// • Autofill hints
  /// • Validation
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    IconData? icon,
    Function(String)? onChanged,
    bool isPasswordField = false,
  }) {
    return AutofillGroup(
      child: TextFormField(
        controller: controller,
        obscureText: isPasswordField ? !_isPasswordVisible : obscure,
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '$label is required';
          }
          return null;
        },
        autofillHints: isPasswordField
            ? const [AutofillHints.password]
            : const [AutofillHints.username],
        style: TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(.4),
          ),
          prefixIcon: icon != null ? Icon(icon, color: Colors.black26) : null,
          suffixIcon: isPasswordField
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    color: _isPasswordVisible ? Colors.black26 : Colors.black54,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
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
          errorStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
