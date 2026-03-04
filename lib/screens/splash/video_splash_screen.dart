import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../LoginPage/controllers/auth_controller.dart';
import '../../LoginPage/services/auth_service.dart';
import '../../LoginPage/services/storage_service.dart';
import '../../Rating/review_service.dart';
import '../../globals.dart';

/// Splash screen that plays a branded video animation (manu.mp4) on app launch.
///
/// Features:
/// - Full-screen video playback with `FittedBox` for proper scaling
/// - Auto-advances after video ends (or on error)
/// - Checks if user has seen onboarding → navigates to Get Started or Login/Home
/// - Uses SharedPreferences to track onboarding status
/// - Handles authentication state via AuthController
class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _videoController;
  late AuthController _authController;
  bool _isVideoInitialized = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _authController = AuthController(
      authService: AuthService(),
      storageService: StorageService(),
    );
    _initializeVideo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        ReviewService().trackAppOpen();
      });
    });
  }

  /// Initializes and starts playing the splash video asset.
  /// Sets up listener and auto-navigation timer on success.
  /// Falls back to navigation on any initialization error.
  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset('assets/manu.mp4');
      await _videoController.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController.play();
        _videoController.addListener(_videoListener);

        // Safety fallback timer in case listener misses end
        final videoDuration = _videoController.value.duration;
        Timer(videoDuration + const Duration(seconds: 1), () {
          if (!_hasNavigated) {
            _navigateToNextScreen();
          }
        });
      }
    } catch (e) {
      _navigateToNextScreen();
    }
  }

  /// Listener that detects when video has nearly finished playing.
  /// Triggers navigation to avoid small timing gaps at end.
  void _videoListener() {
    if (_videoController.value.isInitialized && !_hasNavigated) {
      final position = _videoController.value.position;
      final duration = _videoController.value.duration;
      if (position >= duration - const Duration(milliseconds: 100)) {
        _navigateToNextScreen();
      }
    }
  }

  /// Decides and navigates to the appropriate next screen:
  /// 1. If user hasn't seen onboarding → Get Started
  /// 2. Otherwise → check auth status and route accordingly (login/home)
  Future<void> _navigateToNextScreen() async {
    if (_hasNavigated) return;
    _hasNavigated = true;

    final prefs = await SharedPreferences.getInstance();
    final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

    if (!hasSeenGetStarted) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/get_started');
      }
      return;
    }

    final authModel = await _authController.checkLoginStatus();
    await _authController.handleAuthentication(context, authModel);
  }

  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.primaryColor,
      body: _isVideoInitialized
          ? SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            )
          // Fallback solid color while video initializes
          : Container(
              width: double.infinity,
              height: double.infinity,
              color: AppStyle.primaryColor,
            ),
    );
  }
}
