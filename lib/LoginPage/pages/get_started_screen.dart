import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../globals.dart';

/// Onboarding screen displayed to first-time users after app installation.
///
/// Shows a carousel of feature highlights with images, titles, and descriptions.
/// Allows users to proceed to login after marking onboarding as completed.
///
/// Supports responsive layout across mobile, tablet, and desktop devices.
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

/// State class for [GetStartedScreen].
///
/// Manages:
/// • Carousel slide data and current index tracking
/// • Platform-based image selection
/// • Onboarding completion persistence using SharedPreferences
/// • Navigation to login screen after onboarding completion
class _GetStartedScreenState extends State<GetStartedScreen> {

  /// Returns platform-specific onboarding image asset path.
  ///
  /// Uses iOS-specific images when running on iOS devices,
  /// otherwise defaults to Android/general image assets.
  String _getImagePath(String baseName) {
    if (Platform.isIOS) {
      return 'assets/${baseName}ios.jpg';
    }
    return 'assets/$baseName.jpg';
  }

  /// List of onboarding slide data.
  ///
  /// Each item contains:
  /// • image → Asset path of slide illustration
  /// • title → Slide headline text
  /// • description → Supporting feature explanation
  late final List<Map<String, String>> onboardingData = [
    {
      'image': _getImagePath('1'),
      'title': 'Create Manufacturing Orders',
      'description':
          'Easily create new manufacturing orders, define required materials, and plan your production in just a few steps.',
    },
    {
      'image': _getImagePath('2'),
      'title': 'Start Work Orders',
      'description':
          'Track your production in real time. Start, pause, or complete work orders with a single tap.',
    },
    {
      'image': _getImagePath('3'),
      'title': 'Record Scrap Efficiently',
      'description':
          'Log and manage scrap materials quickly to keep your inventory accurate and your production line optimized.',
    },
  ];

  int currentIndex = 0;

  /// Persists onboarding completion flag in local storage.
  ///
  /// Sets 'hasSeenGetStarted' to true so onboarding is skipped
  /// on subsequent app launches.
  Future<void> _markGetStartedSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenGetStarted', true);
  }

  /// Builds onboarding screen UI.
  ///
  /// Includes:
  /// • Carousel slider for onboarding slides
  /// • Dots indicator for slide position
  /// • "Get Started" action button
  /// • Theme-aware styling and responsive layout
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: CarouselSlider(
                options: CarouselOptions(
                  height: screenHeight * 0.5,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 4),
                  enlargeCenterPage: true,
                  viewportFraction: 0.9,
                  onPageChanged: (index, reason) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                ),
                items: onboardingData.map((data) {
                  return Builder(
                    builder: (BuildContext context) {
                      return Container(
                        width: MediaQuery.of(context).size.width,
                        margin: const EdgeInsets.symmetric(horizontal: 5.0),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 200,
                              width: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image: AssetImage(data['image']!),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Text(
                                data['title']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                              ),
                              child: Text(
                                data['description']!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.textTheme.bodyMedium?.color
                                      ?.withOpacity(0.7),
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

            const SizedBox(height: 20),
            DotsIndicator(
              dotsCount: onboardingData.length,
              position: currentIndex.toDouble(),
              decorator: DotsDecorator(
                activeColor: AppStyle.primaryColor,
                color: AppStyle.primaryColor.withOpacity(0.3),
                size: const Size.square(8.0),
                activeSize: const Size(24.0, 8.0),
                activeShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
            ),

            const SizedBox(height: 30),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _markGetStartedSeen();
                          if (context.mounted) {
                            Navigator.of(
                              context,
                            ).pushReplacementNamed('/login');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFC03355),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
