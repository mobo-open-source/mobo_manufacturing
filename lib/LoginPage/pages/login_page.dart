import 'dart:async';
import 'dart:convert';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/providers/motion_provider.dart';
import '../services/network_service.dart';

import 'credential_page.dart';

/// Login screen for entering server URL and selecting database.
///
/// Features:
/// • URL autocomplete from history
/// • Auto database fetch with debounce
/// • Protocol switching (HTTP / HTTPS)
/// • Manual database entry fallback
/// • Error handling with user-friendly messages
/// • Navigation to credential page after validation
class LoginScreen extends StatefulWidget {
  /// Creates the LoginScreen widget.
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

/// State class for [LoginScreen].
///
/// Manages:
/// • URL input and suggestions
/// • Database list fetching
/// • Error handling and loading states
/// • Form validation and navigation
class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _urlController = TextEditingController();

  String selectedProtocol = 'https://';
  List<String> _databases = [];
  String? _selectedDatabase;
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;
  final _formKey = GlobalKey<FormState>();
  final NetworkService _networkService = NetworkService();
  bool showError = false;
  List<String> _urlSuggestions = [];
  Map<String, Map<String, String>> urlHistory = {};
  String? _workingProtocol;
  bool _showManualDbInput = false;
  final TextEditingController _manualDbController = TextEditingController();

  /// Initializes listeners and loads saved URL history.
  @override
  void initState() {
    super.initState();
    if (_selectedDatabase != null && !_databases.contains(_selectedDatabase)) {
      _selectedDatabase = null;
    }
    _urlController.addListener(_onUrlChanged);
    _manualDbController.addListener(() {
      setState(() {});
    });
    _loadUrlHistory();
  }

  /// Loads saved URL history and prepares autocomplete suggestions.
  ///
  /// Reads from SharedPreferences and reconstructs:
  /// • Full URL suggestions
  /// • Database and username mapping
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

  /// Handles URL input changes with debounce logic.
  ///
  /// After delay:
  /// • Attempts to fetch database list
  /// • Clears state if URL is empty
  void _onUrlChanged() {
    setState(() {
      _isLoading = true;
    });
    final timer = Future.delayed(const Duration(seconds: 2));
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(seconds: 1), () async {
      final url = _urlController.text.trim();
      if (url.isNotEmpty) {
        await _fetchDatabaseList();
        await timer;

        setState(() {
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

  /// Fetches database list from server using available protocols.
  ///
  /// Logic:
  /// • Detects protocol from input OR tries both
  /// • Handles server errors and fallback cases
  /// • Enables manual database entry when needed
  Future<void> _fetchDatabaseList() async {
    try {
      setState(() {
        _isLoading = true;
        _databases.clear();
        _errorMessage = null;
        _workingProtocol = null;
        _showManualDbInput = false;
      });

      String rawUrl = _urlController.text.trim();
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

  /// Converts raw network/server errors into user-friendly messages.
  ///
  /// Handles:
  /// • Network failures
  /// • SSL issues
  /// • Authentication errors
  /// • Server misconfiguration
  /// • Timeout and permission issues
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

  /// Disposes controllers and timers to prevent memory leaks.
  @override
  void dispose() {
    _urlController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Builds main login UI.
  ///
  /// Contains:
  /// • Background and branding
  /// • URL input with autocomplete
  /// • Database selection/manual input
  /// • Error display
  /// • Navigation button
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                image: DecorationImage(
                  image: AssetImage("assets/background.png"),
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
                      return Icon(
                        Icons.precision_manufacturing,
                        color: Color(0xFFC03355),
                        size: 20,
                      );
                    },
                  ),
                  SizedBox(width: 10),
                  Text(
                    'mobo manufacturing',
                    style: const TextStyle(
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
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          'Sign In',
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 32,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'use proper information to continue',
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildInputField(
                          controller: _urlController,
                          label: 'Server URL',
                        ),
                        const SizedBox(height: 16),
                        if (_showManualDbInput) _buildManualDbInput(),
                        if (!_showManualDbInput && _databases.isNotEmpty)
                          _buildDropdown(),
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed:
                                ((_databases.isEmpty && !_showManualDbInput) ||
                                    (_showManualDbInput &&
                                        _manualDbController.text.isEmpty) ||
                                    (!_showManualDbInput &&
                                        _selectedDatabase == null))
                                ? null
                                : () {
                                    setState(() {
                                      showError = true;
                                    });
                                    if (_errorMessage == null) {
                                      if (_formKey.currentState!.validate()) {
                                        var url = _urlController.text.trim();
                                        url = url.replaceFirst(
                                          RegExp(r'^https?://'),
                                          '',
                                        );
                                        String finalDb = _showManualDbInput
                                            ? _manualDbController.text.trim()
                                            : _selectedDatabase!;

                                        if (urlHistory.containsKey(url)) {
                                          final entry = urlHistory[url]!;

                                          if (!_showManualDbInput &&
                                              (_selectedDatabase == null ||
                                                  _selectedDatabase!.isEmpty)) {
                                            finalDb = entry['db'] ?? "";
                                          }
                                        }
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            pageBuilder:
                                                (
                                                  context,
                                                  animation,
                                                  secondaryAnimation,
                                                ) => CredentialsPage(
                                                  protocol:
                                                      _workingProtocol ??
                                                      selectedProtocol,
                                                  url: url,
                                                  database: finalDb,
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
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Next',
                              style: GoogleFonts.manrope(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
          ),
        ],
      ),
    );
  }

  /// Builds server URL input field with autocomplete support.
  ///
  /// Features:
  /// • URL history suggestions
  /// • Protocol selector dropdown
  /// • Loading indicator
  /// • Validation support
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    Function(String)? onChanged,
  }) {
    return RawAutocomplete<String>(
      key: ValueKey(selectedProtocol),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final input = textEditingValue.text.toLowerCase();
        final filtered = _urlSuggestions
            .where((url) => url.toLowerCase().contains(input))
            .toList();

        return filtered;
      },
      onSelected: (String selection) async {
        controller.text = selection;
        if (selection.startsWith('https://')) {
          selectedProtocol = 'https://';
        } else if (selection.startsWith('http://')) {
          selectedProtocol = 'http://';
        } else {
          selectedProtocol = selectedProtocol;
        }
        if (urlHistory.containsKey(selection)) {
          final entry = urlHistory[selection]!;

          _selectedDatabase = entry['db'];
          setState(() {});
        } else {
          await _fetchDatabaseList();
        }
      },

      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
            if (fieldController.text != controller.text) {
              final oldSelection = fieldController.selection;
              fieldController.text = controller.text;
              fieldController.selection = oldSelection;
            }

            focusNode.addListener(() {
              if (focusNode.hasFocus) {
                _loadUrlHistory();
                onChanged?.call(controller.text);
              }
            });

            return TextFormField(
              controller: fieldController,
              focusNode: focusNode,
              obscureText: obscure,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '$label is required';
                }
                return null;
              },
              onChanged: (value) {
                controller.text = value;
                onChanged?.call(value);
              },
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
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          HugeIcons.strokeRoundedServerStack01,
                          size: 20,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        DropdownButtonHideUnderline(
                          child: DropdownButton2<String>(
                            value: selectedProtocol,
                            isExpanded: false,
                            items: ['http://', 'https://']
                                .map(
                                  (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p,
                                  style: GoogleFonts.manrope(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            )
                                .toList(),
                            onChanged: (value) {
                              setState(() => selectedProtocol = value!);
                            },
                            buttonStyleData: ButtonStyleData(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              height: 36,
                              width: 80,
                            ),
                            iconStyleData: const IconStyleData(
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                size: 16,
                                color: Colors.black54,
                              ),
                              iconSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          height: 36,
                          width: 1,
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ],
                    ),
                  ),
                ),

                suffixIcon: _isLoading
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 13,
                          height: 13,
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

  /// Builds manual database input field.
  ///
  /// Used when:
  /// • Server returns no database list
  /// • Manual database entry is required
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
            const SizedBox(width: 10),
            Icon(
              HugeIcons.strokeRoundedDatabase,
              size: 18,
              color: Colors.black54,
            ),
            SizedBox(width: 10),
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

  bool _isDropdownOpened = false;

  /// Builds database dropdown selector.
  ///
  /// Features:
  /// • Removes duplicate database entries
  /// • Validates selected database
  /// • Animated dropdown icon rotation
  Widget _buildDropdown() {
    _databases = _databases.toSet().toList();
    if (!_databases.contains(_selectedDatabase)) {
      _selectedDatabase = null;
    }

    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField2<String>(
        value: _selectedDatabase,
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: Row(
            children: [
              const SizedBox(width: 10),
              const Icon(
                HugeIcons.strokeRoundedDatabase,
                size: 18,
                color: Colors.black54,
              ),
              const SizedBox(width: 10),
              Text(
                _selectedDatabase ?? "Select Database",
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: _selectedDatabase != null
                      ? Colors.black
                      : Colors.black87,
                  fontWeight: _selectedDatabase != null
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 14,
            minHeight: 20,
          ),
          suffixIcon: AnimatedRotation(
            turns: _isDropdownOpened ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: _databases
            .map(
              (db) => DropdownMenuItem<String>(
                value: db,
                child: Text(
                  db,
                  style: GoogleFonts.manrope(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() => _selectedDatabase = value);
        },
        onMenuStateChange: (isOpen) {
          setState(() {
            _isDropdownOpened = isOpen;
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select a database';
          }
          return null;
        },
        dropdownStyleData: DropdownStyleData(
          maxHeight: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          offset: const Offset(0, -4),
        ),
      ),
    );
  }
}
