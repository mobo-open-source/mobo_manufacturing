import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'Dashboard/services/app_bootstrapper.dart';
import 'Dashboard/services/settings_storage_service.dart';
import 'LoginPage/pages/login_page.dart';
import 'MO/pages/MoForm/service/background_timer_service.dart';
import 'core/company/providers/company_provider.dart';
import 'core/providers/motion_provider.dart';
import 'core/providers/theme_provider.dart';
import 'screens/get_started/get_started_screen.dart';
import 'screens/splash/video_splash_screen.dart';
import 'package:provider/provider.dart';

import 'MO/pages/MoForm/service/mo_form_service.dart';
import 'MO/pages/MoList/service/hive/models.dart';
import 'core/navigation/global_keys.dart';

/// Entry point of the application.
///
/// Initializes:
/// - Flutter bindings
/// - Timezone database
/// - Background timer service
/// - Hive (with adapters & boxes for offline caching)
/// - Settings storage
/// - All global providers (motion, theme, company, services)
///
/// Then runs the app wrapped in MultiProvider with reduced motion support.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Start background timer service (periodic sync, etc.)
  final timerService = BackgroundTimerService();
  timerService.initialize();

  // Initialize Hive for local caching (products, BOMs, users, work centers)
  await Hive.initFlutter();

  // Register Hive adapters (only once)
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(HiveProductAdapter());
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(HiveWorkCenterAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HiveBomAdapter());
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(HiveUserModelAdapter());
  }

  // Open required Hive boxes
  if (!Hive.isBoxOpen('products')) await Hive.openBox<HiveProduct>('products');
  if (!Hive.isBoxOpen('bom')) await Hive.openBox<HiveBom>('bom');
  if (!Hive.isBoxOpen('users')) await Hive.openBox<HiveUserModel>('users');
  if (!Hive.isBoxOpen('workCenters')) {
    await Hive.openBox<HiveWorkCenter>('workCenters');
  }

  // Load app settings (e.g. reduce motion preference)
  final settingsStorageService = SettingsStorageService();
  await settingsStorageService.initialize();
  final reduceMotion =
      await settingsStorageService.getBool('reduceMotion') ?? false;

  runApp(
    MultiProvider(
      providers: [
        // Motion/accessibility settings
        ChangeNotifierProvider(create: (_) => MotionProvider()),

        // Theme switching (light/dark)
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        // Ensure motion provider has initial value from storage
        ChangeNotifierProvider(
          create: (_) => MotionProvider()..setReduceMotion(reduceMotion),
        ),

        // Company/session context
        ChangeNotifierProvider(
          create: (_) {
            final p = CompanyProvider();
            p.initialize();
            return p;
          },
        ),

        // Global settings service access
        Provider<SettingsStorageService>.value(value: settingsStorageService),

        // MO form service
        Provider<MoFormService>(create: (_) => MoFormService()),
      ],
      child: AppBootstrapper.provideAll(child: const LoginApp()),
    ),
  );
}

/// Root widget of the application.
///
/// Configures:
/// - MaterialApp with light/dark themes from ThemeProvider
/// - Global navigation & scaffold keys
/// - Fade transitions with reduced motion support
/// - Named routes + onGenerateRoute for dynamic page transitions
class LoginApp extends StatefulWidget {
  const LoginApp({super.key});

  @override
  State<LoginApp> createState() => _LoginAppState();
}

class _LoginAppState extends State<LoginApp> {
  bool isDarkMode = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void toggleTheme(bool value) {
    setState(() {
      isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Login Page',
      // Use dynamic theme from provider
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      // Global keys for scaffold messenger & navigation
      scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => VideoSplashScreen(),
        '/get_started': (context) => GetStartedScreen(),
        '/login': (context) => LoginScreen(),
      },
      // Custom route generator with reduced motion support
      onGenerateRoute: (settings) {
        final motionProvider = Provider.of<MotionProvider>(
          navigatorKey.currentContext!,
          listen: false,
        );

        WidgetBuilder builder;
        switch (settings.name) {
          case '/get_started':
            builder = (_) => const GetStartedScreen();
            break;
          case '/login':
            builder = (_) => const LoginScreen();
            break;
          case '/':
          default:
            builder = (_) => const VideoSplashScreen();
        }

        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
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
        );
      },
    );
  }
}
