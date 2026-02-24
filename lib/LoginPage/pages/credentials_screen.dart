import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:mobo_manufacturing_app/LoginPage/pages/totp_page.dart';
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
import '../services/app_install_check.dart';
import '../services/storage_service.dart';
import '../widgets/login_layout.dart';
import '../bloc/login/login_bloc.dart';
import '../bloc/login/login_event.dart';
import '../bloc/login/login_state.dart';
import 'reset_password.dart';

/// Credentials-based login screen for user authentication.
///
/// This screen allows users to authenticate using:
/// • Username
/// • Password
/// • Server URL configuration (protocol + URL + database)
///
/// Features:
/// • Login state handling using [LoginBloc]
/// • Two-factor authentication (TOTP) redirection support
/// • Manufacturing module validation after login
/// • Secure cleanup of session, storage, and background services if validation fails
/// • URL history storage for quick login reuse
/// • Reduced motion support using [MotionProvider]
/// • Themed login layout using [LoginLayout]
///
/// Navigation Flow:
/// • Login → TOTP screen (if required)
/// • Login → Dashboard (if successful)
/// • Login → Login screen reset (if module missing)
///
/// Security Handling:
/// • Clears SharedPreferences (except onboarding + history)
/// • Clears secure storage credentials
/// • Clears Hive cached business data
/// • Stops background sync services
class CredentialsScreen extends StatefulWidget {
  final String protocol;
  final String url;
  final String database;

  const CredentialsScreen({
    super.key,
    required this.protocol,
    required this.url,
    required this.database,
  });

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

/// State class managing login form UI, validation, and authentication workflow.
///
/// Responsibilities:
/// • Manages login form controllers and validation
/// • Tracks loading and submission states
/// • Handles password visibility toggle
/// • Processes login submission
/// • Handles login state responses from [LoginBloc]
/// • Manages session cleanup and module validation
class _CredentialsScreenState extends State<CredentialsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _submitted = false;
  String? _errorMessage;

  /// Saves login URL configuration to SharedPreferences history.
  ///
  /// Stores:
  /// • Protocol (http/https)
  /// • Server URL (without protocol prefix)
  /// • Database name
  /// • Username
  ///
  /// Behavior:
  /// • Normalizes URL to avoid duplicate protocol prefixes
  /// • Removes duplicate entries before inserting
  /// • Maintains maximum history size of 10 entries
  ///
  /// Used for:
  /// • Quick login reuse
  /// • Recently used server tracking
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

  /// Displays a blocking dialog when required Manufacturing module is not installed.
  ///
  /// Purpose:
  /// • Prevents user from entering app without required backend modules
  /// • Provides clear administrator action message
  ///
  /// Behavior:
  /// • Non-dismissible dialog
  /// • Forces user back to login flow
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

  /// Builds the credentials login UI and wires authentication state handling.
  ///
  /// Responsibilities:
  /// • Provides login layout structure
  /// • Listens to [LoginBloc] state changes
  /// • Navigates based on authentication result:
  ///   - Redirects to TOTP verification screen if required
  ///   - Validates Manufacturing module installation after login
  ///   - Navigates to dashboard if validation passes
  ///   - Clears session and storage if validation fails
  ///
  /// Accessibility:
  /// • Supports reduced motion transitions using [MotionProvider]
  ///
  /// Returns:
  /// • Complete login screen widget tree
  @override
  Widget build(BuildContext context) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return LoginLayout(
      title: 'Sign In',
      subtitle: 'Enter your credentials to continue',
      backButton: Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        child: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: _isLoading ? Colors.white54 : Colors.white,
            size: 24,
          ),
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
      ),
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
              if (context.mounted) {
                showModuleMissingDialog(context);
              }
              return;
            } else {
              AppBootstrapper.reloadAppBlocs(context);
              Navigator.of(context).pushReplacement(
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
              );
            }
          } else if (state.error != null) {
            setState(() {
              _isLoading = false;
              _errorMessage = state.error;
            });
          }
        },
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: _buildCredentialsForm(context, state),
          );
        },
      ),
    );
  }

  /// Stops the running background service if active.
  ///
  /// Used during:
  /// • Forced logout
  /// • Module validation failure cleanup
  /// • Session reset operations
  ///
  /// Ensures background sync or tracking services are safely terminated.
  Future<void> stopBackgroundService() async {
    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();

    if (isRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(seconds: 1));
    } else {}
  }

  /// Builds the login form UI containing credential input fields and actions.
  ///
  /// UI Components:
  /// • Username input field with validation
  /// • Password input field with visibility toggle
  /// • Forgot password navigation link
  /// • Login error message display
  /// • Login submit button with loading animation
  ///
  /// Validation:
  /// • Enables auto validation after first submit attempt
  ///
  /// Returns:
  /// • Column widget containing the full credential form UI
  Widget _buildCredentialsForm(BuildContext context, LoginState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoginTextField(
          controller: _usernameController,
          hint: 'Username',
          prefixIcon: HugeIcons.strokeRoundedUser,
          enabled: !_isLoading,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Username is required';
            }
            return null;
          },
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
        ),

        const SizedBox(height: 16),

        LoginTextField(
          controller: _passwordController,
          hint: 'Password',
          prefixIcon: HugeIcons.strokeRoundedLockPassword,
          obscureText: !_isPasswordVisible,
          enabled: !_isLoading,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible
                  ? HugeIcons.strokeRoundedView
                  : HugeIcons.strokeRoundedViewOff,
              size: 20,
              color: Colors.black54,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Password is required';
            }
            return null;
          },
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
        ),

        const SizedBox(height: 10),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ResetPasswordScreen(
                              url: widget.protocol + widget.url,
                              database: widget.database,
                            ),
                        transitionDuration: const Duration(milliseconds: 300),
                        reverseTransitionDuration: const Duration(
                          milliseconds: 300,
                        ),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    );
                  },
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _isLoading ? Colors.white54 : Colors.white70,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        LoginErrorDisplay(error: _errorMessage),

        LoginButton(
          text: 'Sign In',
          isLoading: _isLoading,
          onPressed: _performLogin,
          loadingWidget: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Signing In',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Validates form input and triggers login authentication request.
  ///
  /// Workflow:
  /// • Validates form fields
  /// • Normalizes URL format
  /// • Saves login configuration to history
  /// • Dispatches [LoginSubmitted] event to [LoginBloc]
  ///
  /// Error Handling:
  /// • Captures exceptions and converts them into user-friendly error messages
  Future<void> _performLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _submitted = true;
      _errorMessage = null;
    });

    try {
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
          username: _usernameController.text.trim(),
          password: _passwordController.text.trim(),
          protocol: widget.protocol,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = _parseLoginError(e.toString());
        _isLoading = false;
        _submitted = false;
      });
    }
  }

  /// Converts raw authentication or network errors into user-friendly messages.
  ///
  /// Handles:
  /// • Invalid credentials errors
  /// • Database configuration errors
  /// • Network / connection issues
  /// • Server internal errors
  /// • Permission and access issues
  ///
  /// Returns:
  /// • Localized user-readable error message
  String _parseLoginError(String error) {
    final errorLower = error.toLowerCase();
    if (errorLower.contains('access denied') ||
        errorLower.contains('invalid login') ||
        errorLower.contains('authentication failed') ||
        errorLower.contains('wrong login/password') ||
        errorLower.contains('invalid username or password') ||
        errorLower.contains('login failed')) {
      return 'Invalid username or password. Please check your credentials and try again.';
    }

    if (errorLower.contains('database') && errorLower.contains('not found')) {
      return 'Database not found. Please check your server configuration.';
    }

    if (errorLower.contains('connection') ||
        errorLower.contains('network') ||
        errorLower.contains('timeout') ||
        errorLower.contains('unreachable')) {
      return 'Unable to connect to server. Please check your internet connection and server URL.';
    }

    if (errorLower.contains('500') ||
        errorLower.contains('internal server error')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    }

    if (errorLower.contains('permission') || errorLower.contains('access')) {
      return 'Access denied. Please check your user permissions.';
    }

    return 'Login failed. Please check your credentials and try again.';
  }
}
