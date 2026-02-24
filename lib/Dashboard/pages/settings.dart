import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:local_auth/local_auth.dart';

import '../../LoginPage/services/storage_service.dart';
import '../../core/providers/motion_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../globals.dart';
import '../../shared/widgets/snackbar.dart';
import '../services/setting_service.dart';
import '../services/settings_storage_service.dart';
import '../widgets/app_web.dart';

/// Main settings screen of the application.
///
/// Contains sections for:
/// - Appearance (theme, motion reduction)
/// - Security (biometric app lock)
/// - Language & Region settings
/// - Data & Storage (cache management)
/// - Help & Support links
/// - About / Company information & social links
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // ──────────────────────────────────────────────
  // Feature toggles (persisted in local storage)
  // ──────────────────────────────────────────────
  bool enableManufacturingDeadline = true;
  bool enableOrderDeadline = true;
  bool showOverviewSmartTab = true;
  bool showProductMoveSmartTab = true;
  bool showTraceabilitySmartTab = true;

  bool darkMode = false;
  bool reduceMotion = false;

  // ──────────────────────────────────────────────
  // Language & Region current values
  // ──────────────────────────────────────────────
  String language = "English (US)";
  String languageCode = "en_US";
  String currency = "United States dollar";
  String timezone = "Europe/Brussels";

  // ──────────────────────────────────────────────
  // Dropdown source data (loaded from Odoo)
  // ──────────────────────────────────────────────
  List<Map<String, dynamic>> _languages = [];
  List<Map<String, dynamic>> _currency = [];
  List<Map<String, dynamic>> _timezone = [];

  late StorageService storageService;
  late SettingsStorageService settingsStorageService;
  bool isLanguageLoading = false;
  int? userId;

  bool _biometricEnabled = false;
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadBiometricPreference();
    storageService = StorageService();
    settingsStorageService = SettingsStorageService();

    // Load persisted settings & user id
    settingsStorageService.initialize().then((_) {
      setState(() {
        userId = settingsStorageService.getInt('userId') ?? userId;
        language = settingsStorageService.getString('language') ?? language;
        currency = settingsStorageService.getString('currency') ?? currency;
        timezone = settingsStorageService.getString('timezone') ?? timezone;
      });
      _initializeOdooClient();
    });
  }

  /// Loads whether biometric authentication is enabled from SharedPreferences.
  Future<void> _loadBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometricEnabled = prefs.getBool('biometricEnabled') ?? false;
    });
  }

  /// Toggles biometric app lock.
  /// Performs device capability check + authentication when enabling.
  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();
      if (canCheck || isSupported) {
        bool authenticated = await _auth.authenticate(
          localizedReason: 'Enable biometric authentication',
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
        );

        if (authenticated) {
          setState(() => _biometricEnabled = true);
          await prefs.setBool('biometricEnabled', true);
        }
      } else {
        CustomSnackbar.showError(
          context,
          'Biometric authentication not supported on this device.',
        );
        setState(() => _biometricEnabled = false);
        await prefs.setBool('biometricEnabled', false);
      }
    } else {
      setState(() => _biometricEnabled = false);
      await prefs.setBool('biometricEnabled', false);
    }

    if (mounted) {
      _biometricEnabled
          ? CustomSnackbar.showSuccess(
              context,
              'Biometric authentication enabled.',
            )
          : CustomSnackbar.showError(
              context,
              'Biometric authentication disabled.',
            );
    }
  }

  /// Initializes Odoo client and loads language/region dropdown data.
  Future<void> _initializeOdooClient() async {
    final settingService = SettingService();
    await settingService.initializeClient();
    await loadLanguageAndRegion(settingService);
  }

  /// Fetches available languages, currencies and timezones from Odoo.
  Future<void> loadLanguageAndRegion(settingService) async {
    setState(() => isLanguageLoading = true);

    try {
      final languages = await settingService.fetchLanguage();
      final currency = await settingService.fetchCurrency();
      final timezone = await settingService.fetchTimezones();

      if (languages != null && currency != null) {
        setState(() {
          _languages = List<Map<String, dynamic>>.from(languages);
          _currency = List<Map<String, dynamic>>.from(currency);
          _timezone = List<Map<String, dynamic>>.from(timezone);
        });
      }
    } catch (_) {
    } finally {
      setState(() => isLanguageLoading = false);
    }
  }

  /// Calculates total size of cache directory in bytes.
  Future<int> getCacheSize() async {
    Directory cacheDir = await getTemporaryDirectory();
    return _getTotalSizeOfFilesInDir(cacheDir);
  }

  /// Recursively calculates size of directory or file.
  Future<int> _getTotalSizeOfFilesInDir(final FileSystemEntity file) async {
    if (file is File) {
      return await file.length();
    }
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      int total = 0;
      for (final child in children) {
        total += await _getTotalSizeOfFilesInDir(child);
      }
      return total;
    }
    return 0;
  }

  /// Deletes entire cache directory (temporary files).
  Future<void> clearCache() async {
    Directory cacheDir = await getTemporaryDirectory();
    await _deleteDir(cacheDir);
  }

  /// Recursively deletes directory contents and itself.
  Future<void> _deleteDir(FileSystemEntity file) async {
    if (file is Directory) {
      final List<FileSystemEntity> children = file.listSync();
      for (final child in children) {
        await _deleteDir(child);
      }
    }
    try {
      await file.delete();
    } catch (_) {}
  }

  /// Loads all user-specific feature toggles from persistent storage.
  Future<void> initializeSettingsStorage() async {
    await settingsStorageService.initialize();
    setState(() {
      enableManufacturingDeadline =
          settingsStorageService.getBool('enableManufacturingDeadline') ?? true;

      enableOrderDeadline =
          settingsStorageService.getBool('enableOrderDate') ?? true;

      showOverviewSmartTab =
          settingsStorageService.getBool('showOverviewSmartTab') ?? true;

      showProductMoveSmartTab =
          settingsStorageService.getBool('showProductMoveSmartTab') ?? true;

      showTraceabilitySmartTab =
          settingsStorageService.getBool('showTraceabilitySmartTab') ?? true;

      darkMode = settingsStorageService.getBool('darkMode') ?? false;
      reduceMotion = settingsStorageService.getBool('reduceMotion') ?? false;
    });
  }

  /// Launches URL in external browser. Throws if cannot be launched.
  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final currencyDisplayKey = 'full_name';

    // Remove duplicates for cleaner currency dropdown
    final uniqueCurrencyItems = _currency
        .map((e) => e[currencyDisplayKey].toString())
        .toSet()
        .map((e) => {currencyDisplayKey: e})
        .toList();
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ──────────────────────────────────────────────
          // Appearance Section
          // ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.dark_mode_outlined,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dark Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Switch between light and dark themes',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isDark
                                    ? Colors.grey[400]!
                                    : Colors.grey[600]!,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FlutterSwitch(
                        width: 60,
                        activeColor: isDark
                            ? Colors.grey[400]!
                            : const Color(0xFFC03355),
                        inactiveColor: isDark ? Colors.black : Colors.white,
                        value: isDark,
                        onToggle: (value) async {
                          themeProvider.toggleTheme();
                          await settingsStorageService.setBool(
                            'darkMode',
                            value,
                          );
                        },
                        activeToggleColor: isDark ? Colors.black : Colors.white,
                        inactiveToggleColor: isDark
                            ? Colors.grey[400]!
                            : const Color(0xFFC03355),
                        showOnOff: false,
                        switchBorder: Border.all(
                          color: isDark
                              ? Colors.grey[400]!
                              : const Color(0xFFC03355),
                          width: 1.5,
                        ),
                        borderRadius: 30.0,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.visibility_off,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reduce Motion',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Minimize animations and motion effect',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isDark
                                    ? Colors.grey[400]!
                                    : Colors.grey[600]!,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FlutterSwitch(
                        width: 60,
                        activeColor: isDark
                            ? Colors.grey[400]!
                            : const Color(0xFFC03355),
                        inactiveColor: isDark ? Colors.black : Colors.white,
                        value: Provider.of<MotionProvider>(
                          context,
                        ).reduceMotion,
                        onToggle: (val) async {
                          Provider.of<MotionProvider>(
                            context,
                            listen: false,
                          ).setReduceMotion(val);
                          await settingsStorageService.setBool(
                            'reduceMotion',
                            val,
                          );
                        },
                        activeToggleColor: isDark ? Colors.black : Colors.white,
                        inactiveToggleColor: isDark
                            ? Colors.grey[400]!
                            : const Color(0xFFC03355),
                        showOnOff: false,
                        switchBorder: Border.all(
                          color: isDark
                              ? Colors.grey[400]!
                              : const Color(0xFFC03355).withOpacity(0.7),
                          width: 1.5,
                        ),
                        borderRadius: 30.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ──────────────────────────────────────────────
          // Security Section
          // ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        HugeIcons.strokeRoundedFingerprintScan,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'App Lock',
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Enable biometric lock to keep your app secure.',
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              style: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isDark
                                    ? Colors.grey[400]!
                                    : Colors.grey[600]!,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      FlutterSwitch(
                        width: 60,
                        activeColor: isDark
                            ? Colors.grey[400]!
                            : const Color(0xFFC03355),
                        inactiveColor: isDark ? Colors.black : Colors.white,
                        value: _biometricEnabled,
                        onToggle: (val) async {
                          await _toggleBiometric(val);
                        },
                        activeToggleColor: isDark ? Colors.black : Colors.white,
                        inactiveToggleColor: isDark
                            ? Colors.grey[400]!
                            : const Color(0xFFC03355),
                        showOnOff: false,
                        switchBorder: Border.all(
                          color: isDark
                              ? Colors.grey[400]!
                              : const Color(0xFFC03355).withOpacity(0.7),
                          width: 1.5,
                        ),
                        borderRadius: 30.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ──────────────────────────────────────────────
          // Language & Region Section
          // ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Language & Region',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () async {
                        setState(() => isLanguageLoading = true);
                        try {
                          final settingService = SettingService();
                          await loadLanguageAndRegion(settingService);
                          setState(() {
                            language =
                                settingsStorageService.getString('language') ??
                                language;
                            currency =
                                settingsStorageService.getString('currency') ??
                                currency;
                            timezone =
                                settingsStorageService.getString('timezone') ??
                                timezone;
                          });
                          CustomSnackbar.showSuccess(
                            context,
                            'Language & Region refreshed',
                          );
                        } catch (e) {
                          CustomSnackbar.showError(
                            context,
                            "Something went wrong please try again later",
                          );
                        } finally {
                          setState(() => isLanguageLoading = false);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildDropdownTile(
                  icon: HugeIcons.strokeRoundedTranslate,
                  title: 'Language',
                  subtitle: 'Select your preferred language',
                  value: language,
                  items: _languages,
                  displayKey: 'name',
                  onChanged: (selectedName) async {
                    if (selectedName != null) {
                      try {
                        final selectedLang = _languages.firstWhere(
                          (lang) => lang['name'] == selectedName,
                          orElse: () => {},
                        );

                        if (selectedLang != null) {
                          final selectedCode = selectedLang['code'];
                          setState(() => language = selectedName);
                          await settingsStorageService.setString(
                            'language',
                            selectedName,
                          );

                          final updatedValue = {
                            'lang': selectedCode,
                            'tz': timezone,
                          };
                          final settingService = SettingService();
                          await settingService.updateLanguage(
                            userId!,
                            updatedValue,
                          );
                          if (mounted) {
                            CustomSnackbar.showSuccess(
                              context,
                              'Language updated successfully',
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomSnackbar.showError(
                            context,
                            'Failed to update language. Please try again later.',
                          );
                        }
                      }
                    }
                  },
                ),

                _buildDropdownTile(
                  icon: HugeIcons.strokeRoundedDollar01,
                  title: 'Currency',
                  subtitle: 'Default currency for transactions',
                  value: currency,
                  items: uniqueCurrencyItems,
                  displayKey: 'full_name',
                  onChanged: (selected) async {
                    if (selected != null) {
                      try {
                        setState(() => currency = selected);
                        await settingsStorageService.setString(
                          'currency',
                          selected,
                        );

                        if (mounted) {
                          CustomSnackbar.showSuccess(
                            context,
                            'Currency updated successfully',
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomSnackbar.showError(
                            context,
                            'Failed to update currency. Please try again later.',
                          );
                        }
                      }
                    }
                  },
                ),

                _buildDropdownTile(
                  icon: HugeIcons.strokeRoundedClock01,
                  title: 'Timezone',
                  subtitle: 'Your local timezone',
                  value: timezone,
                  items: _timezone,
                  displayKey: 'name',
                  onChanged: (selectedName) async {
                    if (selectedName != null) {
                      try {
                        final selectedTz = _timezone.firstWhere(
                          (tz) => tz['name'] == selectedName,
                          orElse: () => {},
                        );

                        if (selectedTz != null) {
                          final selectedCode = selectedTz['code'];
                          setState(() => timezone = selectedName);
                          await settingsStorageService.setString(
                            'timezone',
                            selectedName,
                          );

                          final updatedValue = {
                            'lang': languageCode,
                            'tz': selectedCode,
                          };
                          final settingService = SettingService();

                          await settingService.updateLanguage(
                            userId!,
                            updatedValue,
                          );
                          if (mounted) {
                            CustomSnackbar.showSuccess(
                              context,
                              'Timezone updated successfully',
                            );
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          CustomSnackbar.showError(
                            context,
                            'Failed to update language. Please try again later.',
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          // ──────────────────────────────────────────────
          // Data & Storage Section
          // ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data & Storage',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  title: Text(
                    'Clear Cache',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: FutureBuilder<int>(
                    future: getCacheSize(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return Text('Calculating...');
                      final sizeInMB = (snapshot.data! / (1024 * 1024))
                          .toStringAsFixed(2);
                      return Text(
                        sizeInMB == '0.00'
                            ? 'No cache data'
                            : '$sizeInMB MB • Free up space by clearing temporary data',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      );
                    },
                  ),
                  onTap: () async {
                    await clearCache();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cache cleared successfully'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ──────────────────────────────────────────────
          // Help & Support Section
          // ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                ListTile(
                  leading: Icon(
                    HugeIcons.strokeRoundedHelpCircle,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  title: Text(
                    'Odoo Help Center',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Documentation, guides and resources',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                  onTap: () => _launchUrl("https://www.odoo.com/documentation"),
                ),
                ListTile(
                  leading: Icon(
                    HugeIcons.strokeRoundedCustomerSupport,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  title: Text(
                    'Odoo Support',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Create a ticket with Odoo Support',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                  onTap: () => _launchUrl("https://www.odoo.com/help"),
                ),
                ListTile(
                  leading: Icon(
                    HugeIcons.strokeRoundedUserGroup,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  title: Text(
                    'Odoo Community Forum',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'Ask the community for help',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                  onTap: () => _launchUrl("https://www.odoo.com/forum/help-1"),
                ),
              ],
            ),
          ),

          // ──────────────────────────────────────────────
          // About Section
          // ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.18)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                ListTile(
                  leading: Icon(
                    HugeIcons.strokeRoundedGlobe02,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  title: Text(
                    'Visit Website',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'www.cybrosys.com',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                  onTap: () => _launchUrl("https://www.cybrosys.com"),
                ),
                ListTile(
                  leading: Icon(
                    HugeIcons.strokeRoundedMail01,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  title: Text(
                    'Contact Us',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'info@cybrosys.com',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                  onTap: () => _launchUrl("mailto:info@cybrosys.com"),
                ),
                ListTile(
                  leading: Icon(
                    Icons.apps,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  title: Text(
                    'More Apps',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    'View our other apps on Play Store',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                    ),
                  ),
                  onTap: () => _launchUrl(
                    "https://play.google.com/store/apps/developer?id=Cybrosys",
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Follow Us',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSocialButton(
                      context,
                      'assets/facebook.png',
                      const Color(0xFF1877F2),
                      () => _launchUrlSmart(
                        'https://www.facebook.com/cybrosystechnologies',
                        title: 'Facebook',
                      ),
                    ),
                    _buildSocialButton(
                      context,
                      'assets/linkedin.png',
                      const Color(0xFF0077B5),
                      () => _launchUrlSmart(
                        'https://www.linkedin.com/company/cybrosys/',
                        title: 'LinkedIn',
                      ),
                    ),
                    _buildSocialButton(
                      context,
                      'assets/instagram.png',
                      const Color(0xFFE4405F),
                      () => _launchUrlSmart(
                        'https://www.instagram.com/cybrosystech/',
                        title: 'Instagram',
                      ),
                    ),
                    _buildSocialButton(
                      context,
                      'assets/youtube.png',
                      const Color(0xFFFF0000),
                      () => _launchUrlSmart(
                        'https://www.youtube.com/channel/UCKjWLm7iCyOYINVspCSanjg',
                        title: 'YouTube',
                      ),
                    ),
                    const Divider(height: 32),
                  ],
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    '© ${DateTime.now().year} Cybrosys Technologies',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a circular social media icon button with an underline indicator.
  ///
  /// Displays an asset-based icon inside a rounded container and adds
  /// a colored underline to visually distinguish the platform or action.
  ///
  /// Parameters:
  ///   • [context] - Build context used for theme detection
  ///   • [assetPath] - Asset path of the social media icon image
  ///   • [underlineColor] - Color of the underline indicator below the button
  ///   • [onPressed] - Callback executed when the button is tapped
  ///
  /// Returns:
  ///   A widget representing a styled social icon button.
  Widget _buildSocialButton(
    BuildContext context,
    String assetPath,
    Color underlineColor,
    VoidCallback onPressed,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(.2) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Image.asset(
              assetPath,
              width: 24,
              height: 24,
              color: isDark ? Colors.white : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 48,
          height: 3,
          decoration: BoxDecoration(
            color: underlineColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }

  /// Launches a URL using external apps when possible, otherwise opens in-app.
  ///
  /// Attempts to open the given URL using the device's default external
  /// application (browser or supported app). If not supported, falls back
  /// to opening the page inside the application.
  ///
  /// Parameters:
  ///   • [url] - The URL string to launch
  ///   • [title] - Optional title used when opening inside the app
  ///
  /// Throws:
  ///   May throw URI parsing or launch exceptions handled internally.
  Future<void> _launchUrlSmart(String url, {String? title}) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _openInAppWebPage(uri, title: title);
    }
  }

  /// Opens a web page inside the app using a custom page transition.
  ///
  /// Uses motion settings from [MotionProvider] to determine whether
  /// animations should be reduced or disabled. Displays a fallback
  /// snackbar message if navigation fails.
  ///
  /// Parameters:
  ///   • [url] - Target URL to load inside the web page
  ///   • [title] - Optional title displayed in the web page screen
  ///
  /// Notes:
  ///   • Respects reduced motion accessibility settings
  ///   • Requires widget to be mounted before navigation
  Future<void> _openInAppWebPage(Uri url, {String? title}) async {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    if (!mounted) return;
    try {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              InAppWebPage(url: url, title: title),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open page: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Builds a settings dropdown tile with icon, title, subtitle, and dropdown selector.
  ///
  /// Commonly used for settings selections such as language, currency,
  /// or timezone. Supports theme-based styling and constrained dropdown width.
  ///
  /// Parameters:
  ///   • [icon] - Leading icon displayed in the tile
  ///   • [title] - Main title text of the tile
  ///   • [subtitle] - Supporting description text
  ///   • [value] - Currently selected dropdown value
  ///   • [items] - List of dropdown data maps
  ///   • [displayKey] - Key used to extract display value from items
  ///   • [onChanged] - Callback triggered when selection changes
  ///
  /// Returns:
  ///   A styled ListTile widget with dropdown selector.
  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String? value,
    required List<Map<String, dynamic>> items,
    required String displayKey,
    required ValueChanged<String?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      leading: Icon(icon, color: isDark ? Colors.grey[400] : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 15,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButton<String>(
            value: value,
            items: items.map((item) {
              final itemValue = item[displayKey].toString();
              return DropdownMenuItem<String>(
                value: itemValue,
                child: Text(
                  itemValue,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            underline: const SizedBox(),
            dropdownColor: isDark ? Color(0xFF1F1F1F) : Colors.white,
            isDense: true,
            isExpanded: true,
          ),
        ),
      ),
    );
  }
}
