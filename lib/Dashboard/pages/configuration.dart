import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_manufacturing_app/Dashboard/pages/profile_form.dart';
import 'package:mobo_manufacturing_app/Dashboard/pages/settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

import '../../LoginPage/models/session_model.dart';
import '../../LoginPage/services/storage_service.dart';
import '../../core/company/session/company_session_manager.dart';
import '../../core/providers/motion_provider.dart';
import '../../globals.dart';
import '../models/profile.dart';
import '../services/app_bootstrapper.dart';
import '../services/profile_service.dart';
import '../widgets/logout_dialog.dart';
import 'SwitchAccount/server_url_screen.dart';
import 'dashboard_mo.dart';

/// Configuration / Profile & Account management screen.
///
/// Displays:
/// - Current user profile card (tappable → edit profile)
/// - Settings entry point
/// - Expandable list of saved accounts with switch functionality
/// - Add new account button
/// - Logout option
///
/// Supports dark/light theme, motion reduction preference, and graceful profile fallback.
class Configuration extends StatefulWidget {
  final Uint8List? profileImageBytes;
  final String? userName;
  final String? mail;
  final Future<void> Function()? refreshProfile;

  const Configuration({
    super.key,
    required this.profileImageBytes,
    required this.userName,
    required this.mail,
    this.refreshProfile,
  });

  @override
  State<Configuration> createState() => _ConfigurationState();
}

class _ConfigurationState extends State<Configuration> {
  bool isSwitching = false;
  late StorageService storageService;
  List<Profile> profiles = [];
  String? currentUrl;
  String? currentDatabase;

  @override
  void initState() {
    super.initState();
    storageService = StorageService();
    loadProfile();
    _loadStoredAccounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadStoredAccounts();
  }

  /// Loads the list of stored accounts from SharedPreferences.
  Future<void> _loadStoredAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUrl = prefs.getString('url')??"";
      currentDatabase = prefs.getString('database')??"";
      setState(() {});
    } catch (_) {}
  }

  /// Fetches the current user's profile data from the backend.
  ///
  /// Initializes the [ProfileService] client and loads profile list.
  /// Updates UI via [setState] when data is ready.
  Future<void> loadProfile() async {
    final profileService = ProfileService();
    await profileService.initializeClient();
    profiles = await profileService.loadProfile();
    setState(() {});
  }

  /// Checks if bytes represent an SVG image (looks for `<svg` tag)
  bool isSvgBytes(Uint8List bytes) {
    final str = utf8.decode(bytes, allowMalformed: true);
    return str.contains('<svg');
  }

  /// Checks if base64 string represents an SVG image
  bool isSvgBase64(String data) {
    try {
      final decoded = utf8.decode(base64Decode(data), allowMalformed: true);
      return decoded.contains('<svg');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return WillPopScope(
      onWillPop: () async {
        await widget.refreshProfile?.call();
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.refreshProfile!();
            },
          ),
          title: Text(
            'Configuration',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 22,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Profile Card (tap to edit)
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          ProfileFormPage(refreshProfile: loadProfile),
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppStyle.primaryColor, AppStyle.primaryColor],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: profiles.isNotEmpty && profiles.first.image != null
                                ? isSvgBase64(profiles.first.image!)
                                ? SvgPicture.memory(
                              base64Decode(profiles.first.image!),
                              fit: BoxFit.cover,
                            )
                                : Image.memory(
                              base64Decode(profiles.first.image!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                HugeIcons.strokeRoundedUser,
                                color: Colors.white,
                                size: 30,
                              ),
                            )
                                : widget.profileImageBytes != null
                                ? isSvgBytes(widget.profileImageBytes!)
                                ? SvgPicture.memory(
                              widget.profileImageBytes!,
                              fit: BoxFit.cover,
                            )
                                : Image.memory(
                              widget.profileImageBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                HugeIcons.strokeRoundedUser,
                                color: Colors.white,
                                size: 30,
                              ),
                            )
                                : Icon(
                              HugeIcons.strokeRoundedUser,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profiles.isNotEmpty
                                  ? (profiles.first.name)
                                  : (widget.userName ?? "No Name"),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.mail ?? 'No Email',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white.withOpacity(0.7),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Card containing Settings, Switch Accounts, Logout
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Settings
                    ListTile(
                      leading: Icon(
                        HugeIcons.strokeRoundedSettings02,
                        color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                      ),
                      title: Text(
                        'Settings',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'App preferences and sync options',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder:
                                (context, animation, secondaryAnimation) =>
                                    const SettingsPage(),
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
                                  if (motionProvider.reduceMotion) return child;
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      indent: 20,
                      endIndent: 20,
                    ),

                    // Switch Accounts (Expandable)
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        leading: Icon(
                          HugeIcons.strokeRoundedUserSwitch,
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                        title: Text(
                          'Switch Accounts',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          "Manage and switch between accounts",
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey[400]!
                                : Colors.grey[600]!,
                          ),
                        ),
                        children: [
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: storageService.getAccounts(),
                            builder: (context, snapshot) {
                              final accounts = snapshot.data ?? [];
                              if (accounts.isEmpty) {
                                return  Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedUserAdd01,
                                        size: 30,
                                        color: isDark
                                            ? Colors.grey[600]
                                            : Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        "No Additional Accounts",
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 5,),
                                      Text(
                                        'Add multiple accounts to switch between them quickly',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              final otherAccounts = accounts.where((user) {
                                final userUrl = user['url'] ?? '';
                                final userDatabase = user['database'] ?? '';
                                final userName = user['userName'] ?? '';
                                final userId = user['userId'] ?? '';

                                final currentUserId = profiles.isNotEmpty
                                    ? profiles.first.id
                                    : null;

                                final isSameAccount =
                                    userUrl == currentUrl &&
                                        userDatabase == currentDatabase &&
                                        userId == currentUserId;

                                return !isSameAccount &&
                                    userName.isNotEmpty;
                              }).toList();

                              return Column(
                                children: [
                                  if (otherAccounts.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Icon(
                                            HugeIcons.strokeRoundedUserAdd01,
                                            size: 30,
                                            color: isDark
                                                ? Colors.grey[600]
                                                : Colors.grey[400],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            "No Additional Accounts",
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 5,),
                                          Text(
                                            'Add multiple accounts to switch between them quickly',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ...otherAccounts.map((user) {
                                    Uint8List? avatar;
                                    try {
                                      if (user['image'] != null &&
                                          (user['image'] as String).isNotEmpty) {
                                        avatar = base64Decode(user['image']);
                                      }
                                    } catch (_) {}

                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF434242) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            offset: const Offset(0, -2),
                                            blurRadius: 6,
                                          ),
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            offset: const Offset(0, 3),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: AppStyle.primaryColor,
                                            child: avatar == null
                                                ? const Icon(
                                              HugeIcons.strokeRoundedUser,
                                              color: Colors.white,
                                            )
                                                : isSvgBytes(avatar)
                                                ? ClipOval(
                                              child: SvgPicture.memory(
                                                avatar,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                                : ClipOval(
                                              child: Image.memory(
                                                avatar,
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          title: Builder(
                                            builder: (_) {
                                              final name = user['userName'] ?? '';
                                              final url = user['url'] ?? '';
                                              final db = user['database'] ?? '';

                                              String suffix = "";

                                              if (url != currentUrl) {
                                                suffix = " ($url)";
                                              } else if (db != currentDatabase) {
                                                suffix = " ($db)";
                                              }

                                              return Text.rich(
                                                TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: name,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 16,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                    if (suffix.isNotEmpty)
                                                      TextSpan(
                                                        text: suffix,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.w400,
                                                          fontSize: 13,
                                                          color: Colors.blue[700],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          subtitle: Text(
                                            user['userLogin'] ?? "",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w400,
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.grey[400]!
                                                  : Colors.grey[600]!,
                                            ),
                                          ),
                                          trailing: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                              minimumSize: const Size(50, 28),
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              side: BorderSide(
                                                color: isDark ? Colors.white : AppStyle.primaryColor,
                                                width: 1,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () async {
                                              setState(() {
                                                isSwitching = true;
                                              });
                                              await switchAccount(user);
                                              setState(() {
                                                isSwitching = false;
                                              });
                                            },
                                            child: isSwitching
                                                ? LoadingAnimationWidget.threeArchedCircle(
                                              color: isDark
                                                  ? Colors.white
                                                  : AppStyle.primaryColor,
                                              size: 20,
                                            )
                                                : Text(
                                              "Switch",
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : AppStyle.primaryColor,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 16
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async{
                                          final prefs =
                                              await SharedPreferences
                                              .getInstance();
                                          final url =
                                              prefs.getString('url') ??
                                                  '';
                                          final database =
                                              prefs.getString(
                                                  'database') ??
                                                  '';
                                          final session = await CompanySessionManager.getCurrentSession();

                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder:
                                                  (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                  ) => ServerUrlScreen(
                                                    serverUrl: url,
                                                    database: database,
                                                    session: session!,
                                                  ),
                                              transitionDuration:
                                                  motionProvider.reduceMotion
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 300,
                                                    ),
                                              reverseTransitionDuration:
                                                  motionProvider.reduceMotion
                                                  ? Duration.zero
                                                  : const Duration(
                                                      milliseconds: 300,
                                                    ),
                                              transitionsBuilder:
                                                  (
                                                    context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child,
                                                  ) {
                                                    if (motionProvider
                                                        .reduceMotion) {
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
                                        icon: const Icon(
                                          HugeIcons.strokeRoundedUserAdd01,
                                        ),
                                        label: Text(
                                          "Add Account",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                          foregroundColor: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark ? Colors.grey[800] : Colors.grey.shade200,
                      indent: 20,
                      endIndent: 20,
                    ),

                    // Logout
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Color(0xFFD32F2F),
                      ),
                      title: Text(
                        'Logout',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFFD32F2F),
                          fontWeight: FontWeight.normal,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(
                        'Sign out from this device',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                        ),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) =>
                              LogoutDialog(storageService: storageService),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Switches the active account to the selected one and reloads application state.
  ///
  /// Saves new session, updates login state, reloads blocs/providers,
  /// and navigates to the main dashboard, clearing the navigation stack.
  Future<void> switchAccount(Map<String, dynamic> user) async {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);
    final storageService = StorageService();

    final prefs = await SharedPreferences.getInstance();
    int version = prefs.getInt('version') ?? 0;

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
        version: version,
      ),
    );

    await storageService.saveLoginState(
      isLoggedIn: true,
      database: user['database'],
      url: user['url'],
    );

    if (context.mounted) {
      AppBootstrapper.reloadAppBlocs(context);
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const DashboardMoPage(),
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
        (route) => false,
      );
    }
  }
}
