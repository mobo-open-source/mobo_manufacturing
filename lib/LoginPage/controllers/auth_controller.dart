import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Dashboard/pages/dashboard_mo.dart';
import '../../core/providers/motion_provider.dart';
import '../models/auth_model.dart';
import '../pages/get_started_screen.dart';
import '../pages/login_page.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Controls authentication flow and navigation decisions.
///
/// Responsible for:
/// • Checking stored login status
/// • Handling biometric authentication (if enabled)
/// • Navigating users to the correct screen (Dashboard / Login / Get Started)
///
/// Works as a bridge between UI navigation and authentication services.
class AuthController {
  final AuthService _authService;
  final StorageService _storageService;

  /// Creates an [AuthController].
  ///
  /// Requires:
  /// • [AuthService] for biometric authentication
  /// • [StorageService] for login persistence
  AuthController({
    required AuthService authService,
    required StorageService storageService,
  }) : _authService = authService,
       _storageService = storageService;

  /// Checks whether the user is logged in and if local authentication is enabled.
  ///
  /// Returns an [AuthModel] containing:
  /// • Login status
  /// • Local authentication preference
  Future<AuthModel> checkLoginStatus() async {
    final status = await _storageService.getLoginStatus();
    return AuthModel(
      isLoggedIn: status['isLoggedIn'],
      useLocalAuth: status['useLocalAuth'],
    );
  }

  /// Handles the complete authentication flow and navigates accordingly.
  ///
  /// Flow:
  /// • If user is logged in → Check biometric requirement
  /// • If biometric enabled → Perform biometric authentication
  /// • If authentication succeeds → Navigate to Dashboard
  /// • If authentication fails → Navigate to Login
  /// • If user not logged in → Navigate to Login
  Future<void> handleAuthentication(
    BuildContext context,
    AuthModel authModel,
  ) async {
    if (authModel.isLoggedIn) {
      if (authModel.useLocalAuth) {
        final authResult = await _authService.authenticateWithBiometrics();
        if (authResult == AuthenticationResult.success ||
            authResult == AuthenticationResult.unavailable) {
          await _navigateToDashboard(context);
        } else {
          await _navigateToLogin(context);
        }
      } else {
        await _navigateToDashboard(context);
      }
    } else {
      await _navigateToLogin(context);
    }
  }

  /// Navigates user to the Dashboard screen.
  Future<void> _navigateToDashboard(BuildContext context) async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardMoPage()),
    );
  }

  /// Navigates user to Login or Get Started screen based on app onboarding state.
  ///
  /// Uses:
  /// • MotionProvider → For reduced motion accessibility
  /// • SharedPreferences → To check onboarding completion
  Future<void> _navigateToLogin(BuildContext context) async {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    bool isGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;
    if (isGetStarted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoginScreen(),
          transitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          reverseTransitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (motionProvider.reduceMotion) return child;
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const GetStartedScreen(),
          transitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          reverseTransitionDuration: motionProvider.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (motionProvider.reduceMotion) return child;
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }
}
