import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_snake_navigationbar/flutter_snake_navigationbar.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:provider/provider.dart';

import '../../LoginPage/models/session_model.dart';
import '../../LoginPage/services/storage_service.dart';
import '../../MO/pages/MoList/pages/mo_list.dart';
import '../../Rating/review_service.dart';
import '../../Scrap/pages/scrap_list_page.dart';
import '../../WorkOrders/pages/work_order_list_page.dart';
import '../../core/company/infrastructure/company_refresh_bus.dart';
import '../../core/company/providers/company_provider.dart';
import '../../core/company/widgets/company_selector_widget.dart';
import '../../core/providers/motion_provider.dart';
import '../../service/background_service.dart';
import '../../shared/widgets/snackbar.dart';
import '../infrastructure/profile_refresh_bus.dart';
import '../models/profile.dart';
import '../services/app_bootstrapper.dart';
import '../services/profile_service.dart';

import 'configuration.dart';

/// Main dashboard screen of the manufacturing app.
///
/// Serves as the central hub after login, featuring:
/// - Bottom navigation with Manufacturing Orders (MO), Work Orders, and Scrap
/// - Top app bar with company selector and profile avatar
/// - Real-time profile & company refresh via event buses
/// - In-app review prompt after initial usage
/// - Back-button handling (reset to home or exit app)
///
/// Uses snake-style navigation bar and supports dark/light themes + motion reduction.
class DashboardMoPage extends StatefulWidget {
  const DashboardMoPage({super.key});

  @override
  State<DashboardMoPage> createState() => _DashboardMoPageState();
}

class _DashboardMoPageState extends State<DashboardMoPage> {
  int _currentIndex = 0;
  late StorageService storageService;
  List<Profile> profiles = [];
  String profileImageUrl = '';
  final List<Widget> _pages = const [
    MOListPage(),
    WorkOrderListPage(),
    ScrapListPage(),
  ];
  Uint8List? profileImageBytes;
  String mail = 'Unknown';
  String userName = 'Unknown';
  List<dynamic> loggedInUsers = [];
  late final StreamSubscription profileSub;
  late final StreamSubscription companySub;

  final List<String> _titles = const [
    "Manufacturing Orders",
    "Work Orders",
    "Scrap Items",
  ];

  @override
  void initState() {
    super.initState();
    storageService = StorageService();

    // Listen for profile refresh events
    profileSub = ProfileRefreshBus.onProfileRefresh.listen((_) {
      if (!mounted) return;
      loadProfile();
    });

    // Listen for company refresh events
    companySub = CompanyRefreshBus.stream.listen((_) async {
      if (!mounted) return;
      await context.read<CompanyProvider>().initialize();
      if (!mounted) return;
      AppBootstrapper.reloadAppBlocs(context);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        loadProfile();
        if (mounted) {
          ReviewService().checkAndShowRating(context);
        }
      });
    });
  }

  /// Loads current user profile and updates avatar + account data.
  ///
  /// Also initializes background service, fetches profile from backend,
  /// decodes avatar if available, and syncs it to stored accounts.
  Future<void> loadProfile() async {
    await BackgroundService.initializeService();
    final profileService = ProfileService();
    await profileService.initializeClient();
    await profileService.initializeClient();
    profiles = await profileService.loadProfile();

    final storedAccounts = await storageService.getAccounts();
    setState(() {
      loggedInUsers = storedAccounts;
    });

    if (profiles.isNotEmpty) {
      final profile = profiles.first;
      final base64Image = profile.image;

      mail = profile.mail;
      userName = profile.name;

      await storageService.getLoginStatus();

      // Sync image to stored account
      final currentAccounts = await storageService.getAccounts();

      final existing = currentAccounts.firstWhere(
        (a) => a['userId'] == profile.id,
        orElse: () => {},
      );

      final accountWithImage = {...existing, 'image': base64Image};

      await storageService.saveAccount(accountWithImage);

      if (base64Image.isNotEmpty) {
        Uint8List imageBytes = base64Decode(base64Image);
        setState(() {
          profileImageBytes = imageBytes;
        });
      }
    }
  }

  /// Builds items for the bottom snake navigation bar
  List<BottomNavigationBarItem> _navBarItems() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return [
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Icon(HugeIcons.strokeRoundedFactory02),
        ),
        label: 'MO',
        activeIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Icon(
            HugeIcons.strokeRoundedFactory02,
            color: isDark ? Colors.white : colorScheme.primary,
          ),
        ),
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Icon(HugeIcons.strokeRoundedSettings02),
        ),
        label: 'Work Order',
        activeIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Icon(
            HugeIcons.strokeRoundedSettings02,
            color: isDark ? Colors.white : colorScheme.primary,
          ),
        ),
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Icon(HugeIcons.strokeRoundedDelete02),
        ),
        label: 'Scrap',
        activeIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Icon(
            HugeIcons.strokeRoundedDelete02,
            color: isDark ? Colors.white : colorScheme.primary,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false;
        }
        SystemNavigator.pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: Text(
            _titles[_currentIndex],
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
              fontSize: 22,
            ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            SizedBox(
              width: 160,
              child: CompanySelectorWidget(
                onCompanyChanged: () async {
                  if (!mounted) return;
                  final provider = context.read<CompanyProvider>();
                  final companyName =
                      provider.selectedCompany?['name']?.toString() ??
                      'company';
                  await loadProfile();
                  CompanyRefreshBus.notify();

                  CustomSnackbar.showSuccess(
                    context,
                    'Switched to $companyName',
                  );
                },
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        Configuration(
                          refreshProfile: loadProfile,
                          profileImageBytes: profileImageBytes,
                          userName: userName.isNotEmpty ? userName : "Unknown",
                          mail: mail.isNotEmpty ? mail : "Unknown",
                        ),
                    transitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    reverseTransitionDuration: motionProvider.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          if (motionProvider.reduceMotion) return child;
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.surface,
                  backgroundImage: profileImageBytes != null
                      ? MemoryImage(profileImageBytes!)
                      : null,
                  child: profileImageBytes == null
                      ? Icon(
                          Icons.person,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        body: _pages[_currentIndex],
        bottomNavigationBar: SnakeNavigationBar.color(
          behaviour: SnakeBarBehaviour.pinned,
          snakeShape: SnakeShape.indicator,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          selectedItemColor: isDark ? Colors.white : theme.primaryColor,
          unselectedItemColor: isDark ? Colors.grey[400] : Colors.black,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: _navBarItems(),
          snakeViewColor: isDark ? Colors.white : theme.primaryColor,
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          selectedLabelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : theme.primaryColor,
          ),
          shadowColor: isDark ? Colors.black26 : Colors.grey[200]!,
          elevation: 8,
          height: 70,
        ),
      ),
    );
  }

  /// **Deprecated / unused in current implementation**
  ///
  /// Previously used to switch accounts directly from dashboard.
  /// Now handled in Configuration screen.
  Future<void> switchAccount(Map<String, dynamic> user) async {
    final storageService = StorageService();

    await storageService.saveSession(
      SessionModel(
        sessionId: user['sessionId'],
        userName: user['userName'],
        userLogin: user['userLogin'],
        userId: user['userId'],
        serverVersion: user['serverVersion'],
        userLang: user['userLang'],
        partnerId: user['partnerId'],
        userTimezone: user['userTimezone'],
        companyId: user['companyId'],
        companyName: user['companyName'],
        isSystem: user['isSystem'] ?? false,
      ),
    );

    await storageService.saveLoginState(
      isLoggedIn: true,
      database: user['database'],
      url: user['url'],
    );
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardMoPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }
}
