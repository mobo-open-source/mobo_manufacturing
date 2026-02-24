import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/colors/app_colors.dart';
import '../../LoginPage/controllers/auth_controller.dart';
import '../../LoginPage/services/auth_service.dart';
import '../../LoginPage/services/storage_service.dart';

/// Onboarding / "Get Started" screen shown on first app launch.
///
/// Displays a full-screen carousel with manufacturing feature highlights.
/// Allows users to proceed to login and stores onboarding completion state.
///
/// If onboarding was already completed, automatically checks authentication
/// status and redirects user accordingly.
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

/// State class for [GetStartedScreen].
///
/// Handles:
/// • Authentication state check using [AuthController]
/// • Onboarding completion persistence using SharedPreferences
/// • Carousel slide management and index tracking
/// • Platform-specific image selection (iOS / Android)
/// • Responsive layout adjustments (portrait / landscape)
class _GetStartedScreenState extends State<GetStartedScreen> {
  late AuthController _authController;

  /// Returns platform-specific onboarding image asset path.
  ///
  /// Uses iOS-specific images when running on iOS devices,
  /// otherwise defaults to standard image assets.
  String _getImagePath(String baseName) {
    if (Platform.isIOS) {
      return 'assets/${baseName}ios.jpg';
    }
    return 'assets/$baseName.jpg';
  }

  /// List of onboarding slide content.
  ///
  /// Each slide contains:
  /// • image → Platform-specific asset path
  /// • title → Main feature heading
  /// • subtitle → Supporting description text
  late final List<Map<String, String>> slides = [
    {
      'image': _getImagePath('1'),
      'title': 'Streamline Your\nManufacturing Process',
      'subtitle':
          'Manage production orders, track inventory, and optimize workflows with ease.',
    },
    {
      'image': _getImagePath('2'),
      'title': 'Real-time Production\nMonitoring',
      'subtitle':
          'Track work orders, monitor progress, and ensure quality control in real-time.',
    },
    {
      'image': _getImagePath('3'),
      'title': 'Efficient Resource\nManagement',
      'subtitle':
          'Optimize material usage, manage work centers, and reduce production costs.',
    },
  ];

  int currentIndex = 0;

  /// Initializes authentication controller and checks onboarding/auth state.
  ///
  /// If onboarding was already completed:
  /// → Validates user session
  /// → Navigates user to appropriate authenticated screen
  @override
  void initState() {
    super.initState();
    _authController = AuthController(
      authService: AuthService(),
      storageService: StorageService(),
    );
    _checkAuthenticationStatus();
  }

  /// Verifies whether onboarding was previously completed.
  ///
  /// If completed:
  /// → Checks login session using [AuthController]
  /// → Navigates user based on authentication state
  Future<void> _checkAuthenticationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGetStarted = prefs.getBool('hasSeenGetStarted') ?? false;

    if (hasSeenGetStarted) {
      final authModel = await _authController.checkLoginStatus();
      await _authController.handleAuthentication(context, authModel);
    }
  }

  /// Stores onboarding completion flag in local storage.
  ///
  /// Sets 'hasSeenGetStarted' to true so onboarding is skipped
  /// on future app launches.
  Future<void> _markGetStartedSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenGetStarted', true);
  }

  /// Builds onboarding screen UI.
  ///
  /// Includes:
  /// • Fullscreen image carousel with overlay gradient
  /// • Slide title and subtitle content
  /// • "Get Started" action button
  /// • Slide position dots indicator
  /// • Landscape and portrait responsive layout handling
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CarouselSlider(
              options: CarouselOptions(
                height: double.infinity,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 4),
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                enlargeCenterPage: false,
                viewportFraction: 1.0,
                scrollDirection: Axis.horizontal,
                onPageChanged: (index, reason) {
                  setState(() {
                    currentIndex = index;
                  });
                },
              ),
              items: slides.map((slide) {
                return Builder(
                  builder: (BuildContext context) {
                    return SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            slide['image']!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[900],
                                child: const Center(
                                  child: Icon(
                                    Icons.precision_manufacturing,
                                    color: Colors.white54,
                                    size: 50,
                                  ),
                                ),
                              );
                            },
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.2),
                                  Colors.black.withOpacity(0.5),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape =
                    constraints.maxWidth > constraints.maxHeight;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 60 : 40,
                    vertical: isLandscape ? 20 : 40,
                  ),
                  child: Column(
                    children: [
                      const Spacer(),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slides[currentIndex]['title']!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSans(
                              fontSize: isLandscape ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isLandscape ? 10 : 15),
                          Text(
                            slides[currentIndex]['subtitle']!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSans(
                              fontSize: isLandscape ? 14 : 16,
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: isLandscape ? 30 : 40),
                          SizedBox(
                            height: isLandscape ? 45 : 55,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                await _markGetStartedSeen();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/login',
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 8,
                                shadowColor: AppColors.primary.withOpacity(0.3),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                "Get Started",
                                style: GoogleFonts.notoSans(
                                  fontSize: isLandscape ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isLandscape ? 15 : 20),

                          DotsIndicator(
                            dotsCount: slides.length,
                            position: currentIndex.toDouble(),
                            decorator: DotsDecorator(
                              activeColor: Colors.white,
                              color: Colors.white.withOpacity(0.4),
                              size: Size.square(isLandscape ? 6.0 : 8.0),
                              activeSize: Size(
                                isLandscape ? 12.0 : 16.0,
                                isLandscape ? 6.0 : 8.0,
                              ),
                              activeShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                            ),
                          ),

                          SizedBox(height: isLandscape ? 10 : 20),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
