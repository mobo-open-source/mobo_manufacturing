import 'dart:async';
import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_manufacturing_app/Dashboard/pages/SwitchAccount/switch_credentials_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../LoginPage/models/session_model.dart';
import '../../../LoginPage/services/network_service.dart';
import '../dashboard_mo.dart';

/// Screen for entering and validating the Odoo server URL and database selection.
///
/// This is typically the first screen in the multi-account / switch-account flow.
/// It allows the user to:
/// - Input server address (with http/https protocol selection)
/// - See previously used servers as autocomplete suggestions
/// - Automatically fetch available databases from the server
/// - Select a database from the list or manually enter one
/// - Proceed to credentials login once server + database are valid
///
/// Features:
/// - Protocol auto-detection and fallback (tries HTTPS → HTTP)
/// - Debounced URL validation with loading indicator
/// - History persistence via SharedPreferences (last 10 entries)
/// - User-friendly error messages for common connection issues
/// - Dark/light theme background support
class ServerUrlScreen extends StatefulWidget {
  final String serverUrl;
  final String database;
  final SessionModel session;

  const ServerUrlScreen({
    super.key,
    required this.serverUrl,
    required this.database,
    required this.session,
  });

  @override
  State<ServerUrlScreen> createState() => _ServerUrlScreenState();
}

class _ServerUrlScreenState extends State<ServerUrlScreen> {
  // ────────────────────────────────────────────────
  // State variables
  // ────────────────────────────────────────────────
  final TextEditingController _urlController = TextEditingController();
  String _url = '';
  List<String> _urlSuggestions = [];
  Map<String, Map<String, String>> urlHistory = {};
  List<String> _databases = [];
  String? _selectedDatabase;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showManualDbInput = false;
  bool hideHistorySuggestions = false;
  final TextEditingController _manualDbController = TextEditingController();
  Timer? _debounce;
  String selectedProtocol = 'https://';
  bool showError = false;
  String? _workingProtocol;

  final NetworkService _networkService = NetworkService();

  // ────────────────────────────────────────────────
  // Lifecycle
  // ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _manualDbController.addListener(() {
      setState(() {});
    });
    _loadUrlHistory();
    _prefillData();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _manualDbController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Initializes form fields with widget-provided server URL and database.
  ///
  /// - Splits protocol from URL and updates text controller
  /// - Fetches available databases from server
  /// - Auto-selects database if it exists, else enables manual input
  /// - Calls `setState()` to reflect changes
  Future<void> _prefillData() async {
    if (widget.serverUrl.isEmpty) return;

    String url = widget.serverUrl.trim();

    // Detect protocol
    if (url.startsWith('http://')) {
      selectedProtocol = 'http://';
      url = url.replaceFirst('http://', '');
    } else if (url.startsWith('https://')) {
      selectedProtocol = 'https://';
      url = url.replaceFirst('https://', '');
    }

    _url = url;
    _urlController.text = url;

    // Fetch DB list
    await _fetchDatabaseList(url);

    if (widget.database.isNotEmpty) {
      if (_databases.contains(widget.database)) {
        _selectedDatabase = widget.database;
        _showManualDbInput = false;
      } else {
        _showManualDbInput = true;
        _manualDbController.text = widget.database;
      }
    }

    setState(() {});
  }

  // ────────────────────────────────────────────────
  // History persistence
  // ────────────────────────────────────────────────

  /// Loads previously saved server URLs + associated metadata from SharedPreferences.
  Future<void> _loadUrlHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final urls = prefs.getStringList('urlHistory') ?? [];
    _urlSuggestions.clear();
    urlHistory.clear();
    for (String entry in urls) {
      try {
        final decoded = jsonDecode(entry);
        final url = decoded['url'] ?? '';
        final protocol = decoded['protocol'] ?? 'https://';
        final fullUrl = '$protocol$url';
        _urlSuggestions.add(fullUrl);
        urlHistory[fullUrl] = {
          'db': decoded['db'] ?? '',
          'username': decoded['username'] ?? '',
        };
      } catch (_) {
        if (entry.isNotEmpty) {
          _urlSuggestions.add(entry);
          urlHistory[entry] = {'db': '', 'username': '', 'password': ''};
        }
      }
    }
    _urlSuggestions = _urlSuggestions.toSet().toList();
    setState(() {});
  }

  /// Saves the current server + database + username to history (most recent first).
  /// Keeps only the last 10 entries.
  Future<void> saveUrlHistory({
    required String protocol,
    required String url,
    required String database,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('urlHistory') ?? [];
    String finalProtocol = protocol;
    String finalUrl = url.trim();
    if (finalUrl.startsWith('https://')) {
      finalProtocol = 'https';
      finalUrl = finalUrl.replaceFirst('https://', '');
    } else if (finalUrl.startsWith('http://')) {
      finalProtocol = 'http';
      finalUrl = finalUrl.replaceFirst('http://', '');
    }
    final entry = jsonEncode({
      'protocol': finalProtocol,
      'url': finalUrl,
      'db': database,
      'username': username,
    });

    // Remove older entry with same server
    history.removeWhere((e) {
      final d = jsonDecode(e);
      return d['url'] == finalUrl && d['protocol'] == finalProtocol;
    });
    history.insert(0, entry);
    await prefs.setStringList('urlHistory', history.take(10).toList());
  }

  // ────────────────────────────────────────────────
  // Business logic
  // ────────────────────────────────────────────────

  /// Debounced handler for URL input changes → triggers database discovery
  Future<void> _handleUrlChanged(String value) async {
    setState(() {
      _isLoading = true;
    });
    final timer = Future.delayed(const Duration(seconds: 2));
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () async {
      final url = value.trim();
      if (url.isNotEmpty) {
        await _fetchDatabaseList(url);
        await timer;

        setState(() {
          _url = value;
          _isLoading = false;
        });
      } else {
        setState(() {
          _databases = [];
          _selectedDatabase = null;
          _isLoading = false;
        });
      }
    });
  }

  /// Tries to connect to the server (with protocol fallback) and retrieve list of databases.
  Future<void> _fetchDatabaseList(String url) async {
    try {
      setState(() {
        _isLoading = true;
        _databases.clear();
        _errorMessage = null;
        _workingProtocol = null;
        _showManualDbInput = false;
      });

      String rawUrl = url;
      final match = RegExp(
        r'^(https?://)',
        caseSensitive: false,
      ).firstMatch(rawUrl);

      List<String> protocolsToTry = [];
      String host;

      if (match != null) {
        String detectedProtocol = match.group(1)!.toLowerCase();
        protocolsToTry = [detectedProtocol];
        host = rawUrl.substring(detectedProtocol.length);
      } else {
        host = rawUrl;
        protocolsToTry = [selectedProtocol];
        protocolsToTry.add(
          selectedProtocol == 'https://' ? 'http://' : 'https://',
        );
      }

      bool success = false;
      dynamic lastError;

      for (String protocol in protocolsToTry) {
        try {
          final dbList = await _networkService.fetchDatabaseList(
            '$protocol$host',
          );
          if (dbList.isNotEmpty) {
            setState(() {
              _databases = dbList;
              _workingProtocol = protocol;
              _errorMessage = null;
              if (dbList.length == 1) {
                _selectedDatabase = dbList.first;
              }
            });
            success = true;
            break;
          } else {
            setState(() {
              _workingProtocol = protocol;
              _databases = [];
              _showManualDbInput = true;
              _errorMessage = null;
            });
            success = true;
            break;
          }
        } catch (error) {
          if (error is Map && error.containsKey('data')) {
            setState(() {
              _workingProtocol = protocol;
              _databases = [];
              _showManualDbInput = true;
              _errorMessage = null;
            });
            success = true;
            break;
          }
          lastError = error;
        }
      }
      if (!success) {
        setState(() {
          _databases = [];
          _selectedDatabase = null;
          showError = true;
          _showManualDbInput = false;
          _errorMessage = _formatLoginError(lastError);
          _workingProtocol = null;
        });
      }
    } catch (e) {
      setState(() {
        showError = true;
        _errorMessage = _formatLoginError(e);
        _databases = [];
        _selectedDatabase = null;
        _showManualDbInput = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Maps common network/login errors to human-readable messages.
  String _formatLoginError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('html instead of json') ||
        errorStr.contains('formatexception')) {
      return 'Server configuration issue. This may not be an Odoo server or the URL is incorrect.';
    } else if (errorStr.contains('invalid login') ||
        errorStr.contains('wrong credentials')) {
      return 'Incorrect email or password. Please check your login credentials.';
    } else if (errorStr.contains('user not found') ||
        errorStr.contains('no such user')) {
      return 'User account not found. Please check your email address or contact your administrator.';
    } else if (errorStr.contains('database') &&
        errorStr.contains('not found')) {
      return 'Selected database is not available. Please choose a different database.';
    } else if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return 'Connection timed out. The server may be slow or unreachable.';
    } else if (errorStr.contains('unauthorized') || errorStr.contains('403')) {
      return 'Access denied. Your account may not have permission to access this database.';
    } else if (errorStr.contains('server') || errorStr.contains('500')) {
      return 'Server error occurred. Please try again later or contact your administrator.';
    } else if (errorStr.contains('ssl') || errorStr.contains('certificate')) {
      return 'SSL connection failed. Try using HTTP instead of HTTPS.';
    } else if (errorStr.contains('connection refused')) {
      return 'Server is not responding. Please verify the server URL and try again.';
    } else if (errorStr.contains('connection terminated during handshake')) {
      return 'Secure connection failed. The server may not support HTTPS or has an invalid SSL certificate. Try switching to HTTP or contact your administrator.';
    } else {
      return 'Network error occurred. Please check your internet connection and server URL';
    }
  }

  // ────────────────────────────────────────────────
  // UI Building
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DashboardMoPage()),
        );
        return false;
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Background gradient + subtle texture
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[950] : Colors.grey[50],
                  image: DecorationImage(
                    image: const AssetImage("assets/background.png"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      isDark
                          ? Colors.black.withOpacity(1)
                          : Colors.white.withOpacity(1),
                      BlendMode.dstATop,
                    ),
                  ),
                ),
              ),
            ),

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
                        : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DashboardMoPage(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      height: 64,
                      width: 64,
                      alignment: Alignment.center,
                      child: Icon(
                        HugeIcons.strokeRoundedArrowLeft01,
                        color: _isLoading ? Colors.white54 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Header logo + app name
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
                        return const Icon(
                          Icons.precision_manufacturing,
                          color: Color(0xFFC03355),
                          size: 20,
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'mobo manufacturing',
                      style: TextStyle(
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

            // Main content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        const SizedBox(height: 45),
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            "Add Account",
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 25,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Enter your server details to continue',
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 30),

                        // URL + protocol input with autocomplete
                        _UrlInputField(
                          controller: _urlController,
                          protocol: selectedProtocol,
                          url: _url,
                          isLoading: _isLoading,
                          urlSuggestions: _urlSuggestions,
                          urlHistory: urlHistory,
                          hideHistorySuggestions: hideHistorySuggestions,
                          onUrlChanged: _handleUrlChanged,
                          onProtocolChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedProtocol = value);
                            if (_url.isNotEmpty) _handleUrlChanged(_url);
                          },
                          onDatabaseSelected: (db) {
                            setState(() => _selectedDatabase = db);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Manual DB input or dropdown
                        if (_showManualDbInput) _buildManualDbInput(),
                        if (!_showManualDbInput && _databases.isNotEmpty)
                          _DatabaseDropdown(
                            databases: _databases,
                            selectedDatabase: _selectedDatabase,
                            onDatabaseChanged: (db) =>
                                setState(() => _selectedDatabase = db),
                          ),

                        // Error message
                        if (showError) ...[
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.manrope(color: Colors.white),
                              ),
                            ),
                        ],
                        const SizedBox(height: 30),

                        // Next button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: ((_databases.isEmpty && !_showManualDbInput) ||
                                (_showManualDbInput && _manualDbController.text.isEmpty) ||
                                (!_showManualDbInput && _selectedDatabase == null))
                                ? null
                                : () {
                                    setState(() {
                                      showError = true;
                                    });
                                    var url = _url.trim();
                                    url = url.replaceFirst(
                                      RegExp(r'^https?://'),
                                      '',
                                    );
                                    String finalDb = _showManualDbInput
                                        ? _manualDbController.text.trim()
                                        : _selectedDatabase!;
                                    if (finalDb.isEmpty) {
                                      setState(
                                            () => _errorMessage =
                                        "Database name is required",
                                      );
                                      return;
                                    }
                                    if (urlHistory.containsKey(url)) {
                                      final entry = urlHistory[url]!;

                                      if (!_showManualDbInput && (_selectedDatabase == null ||
                                          _selectedDatabase!.isEmpty)) {
                                        finalDb = entry['db'] ?? "";
                                      }
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SwitchCredentialsScreen(
                                          serverUrl: url,
                                          database: finalDb,
                                          protocol:
                                              _workingProtocol ??
                                              selectedProtocol,
                                          urlInput: _url,
                                          session: widget.session,
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Checking',
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
                                : const Text(
                                    'Next',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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

  Widget _buildManualDbInput() {
    return TextFormField(
      controller: _manualDbController,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Database name is required';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: 'Enter Database Name',
        hintStyle: GoogleFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withOpacity(.4),
        ),
        prefixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 6),
            Icon(
              HugeIcons.strokeRoundedDatabase,
              size: 18,
              color: Colors.black54,
            ),
            const SizedBox(width: 12),
          ],
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 14,
          minHeight: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _UrlInputField extends StatelessWidget {
  final TextEditingController controller;
  final String protocol;
  final String url;
  final bool isLoading;
  final List<String> urlSuggestions;
  final Map<String, Map<String, String>> urlHistory;
  final void Function(String) onUrlChanged;
  final void Function(String?) onProtocolChanged;
  final void Function(String) onDatabaseSelected;
  final bool hideHistorySuggestions;

  const _UrlInputField({
    required this.controller,
    required this.protocol,
    required this.url,
    required this.isLoading,
    required this.urlSuggestions,
    required this.urlHistory,
    required this.onUrlChanged,
    required this.onProtocolChanged,
    required this.onDatabaseSelected,
    required this.hideHistorySuggestions,
  });

  @override
  Widget build(BuildContext context) {
    final validProtocols = ['http://', 'https://'];
    return RawAutocomplete<String>(
      optionsBuilder: (value) {
        if (hideHistorySuggestions) return const Iterable<String>.empty();

        final input = value.text.trim().toLowerCase();
        if (input.isEmpty) return const Iterable<String>.empty();

        return urlSuggestions.where((u) => u.toLowerCase().contains(input));
      },

      onSelected: (selection) {
        onUrlChanged(selection);
        final entry = urlHistory[selection];
        if (entry != null && entry['db']?.isNotEmpty == true) {
          onDatabaseSelected(entry['db']!);
        }
      },

      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Server address is required';
            }
            return null;
          },
          onChanged: onUrlChanged,
          style: GoogleFonts.manrope(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: "Enter Server Address",
            hintStyle: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black.withOpacity(.4),
            ),
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 8),
                const Icon(
                  HugeIcons.strokeRoundedServerStack01,
                  size: 20,
                  color: Colors.black54,
                ),
                SizedBox(width: 10),
                DropdownButtonHideUnderline(
                  child: DropdownButton2<String>(
                    value: validProtocols.contains(protocol)
                        ? protocol
                        : 'https://',
                    isExpanded: false,
                    items: validProtocols
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(
                              p,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: onProtocolChanged,
                    buttonStyleData: ButtonStyleData(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      height: 36,
                      width: MediaQuery.of(context).size.width * 0.23,
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      offset: const Offset(0, -3),
                    ),
                    iconStyleData: const IconStyleData(
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: Colors.black54,
                      ),
                      iconSize: 18,
                      iconEnabledColor: Colors.black54,
                      openMenuIcon: Icon(
                        Icons.keyboard_arrow_up,
                        size: 16,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            suffixIcon: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.black54,
                        ),
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () {
                      onSelected(option);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        option,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DatabaseDropdown extends StatelessWidget {
  final List<String> databases;
  final String? selectedDatabase;
  final void Function(String?) onDatabaseChanged;

  const _DatabaseDropdown({
    required this.databases,
    required this.selectedDatabase,
    required this.onDatabaseChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (databases.isEmpty) return const SizedBox.shrink();

    return DropdownButtonFormField2<String>(
      value: selectedDatabase,
      isExpanded: true,
      hint: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Select Database",
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(.4),
          ),
        ),
      ),
      items: databases
          .map(
            (db) => DropdownMenuItem(
              value: db,
              child: Text(
                db,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: onDatabaseChanged,
      decoration: InputDecoration(
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 8, right: 0),
          child: Icon(
            HugeIcons.strokeRoundedDatabase,
            size: 18,
            color: Colors.black54,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 14,
          minHeight: 20,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        offset: const Offset(0, -4),
      ),
      iconStyleData: const IconStyleData(
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
      ),
    );
  }
}
