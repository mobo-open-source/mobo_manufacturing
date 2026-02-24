import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:async';

/// Generic in-app browser screen using WebView.
///
/// Loads and displays external web content inside the app.
/// Supports navigation controls, pull-to-refresh, loading progress,
/// and error handling with retry option.
class WebViewPage extends StatefulWidget {
  final String url;
  final String title;

  const WebViewPage({super.key, required this.url, required this.title});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

/// State class for [WebViewPage].
///
/// Handles:
/// • WebView initialization and configuration
/// • Page loading progress tracking
/// • Navigation control (back / forward / system back)
/// • Pull-to-refresh handling
/// • Web resource error handling and retry support
/// • Theme-aware UI styling
class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool isLoading = true;
  String? _errorMessage;
  int _loadingProgress = 0;

  /// Completer used to synchronize pull-to-refresh lifecycle
  /// with WebView page loading completion.
  Completer<void>? _refreshCompleter;

  /// Initializes WebView configuration and navigation delegates.
  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  /// Configures WebView controller and navigation callbacks.
  ///
  /// Handles:
  /// • JavaScript enablement
  /// • Loading progress updates
  /// • Page start and finish state
  /// • Web resource error detection
  /// • Initial URL loading
  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _loadingProgress = progress;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
              _errorMessage = null;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
            });
            _refreshCompleter?.complete();
            _refreshCompleter = null;
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              isLoading = false;
              _errorMessage = 'Failed to load page: ${error.description}';
            });
            _refreshCompleter?.completeError(error);
            _refreshCompleter = null;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Reloads current WebView page and resets loading/error state.
  void _refresh() {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    _controller.reload();
  }

  /// Navigates WebView back if possible,
  /// otherwise exits the screen.
  void _goBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
    } else {
      Navigator.pop(context);
    }
  }

  /// Navigates WebView forward if forward history exists.
  void _goForward() async {
    if (await _controller.canGoForward()) {
      _controller.goForward();
    }
  }

  /// Intercepts system back button behavior.
  ///
  /// Navigates back inside WebView if history exists,
  /// otherwise allows screen pop.
  Future<bool> _handleWillPop() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
      return false;
    }
    return true;
  }

  /// Builds WebView screen UI.
  ///
  /// Includes:
  /// • App bar with navigation controls
  /// • Page loading progress indicator
  /// • Pull-to-refresh support
  /// • WebView content or error fallback UI
  /// • Theme-aware styling
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          elevation: 0,
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          leading: IconButton(
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              } else {
                if (mounted) Navigator.pop(context);
              }
            },
            icon: const Icon(HugeIcons.strokeRoundedArrowLeft01, size: 20),
          ),
          title: Text(
            widget.title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              onPressed: _goBack,
              icon: const Icon(HugeIcons.strokeRoundedArrowLeft02, size: 20),
              tooltip: 'Back',
            ),
            IconButton(
              onPressed: _goForward,
              icon: const Icon(HugeIcons.strokeRoundedArrowRight02, size: 20),
              tooltip: 'Forward',
            ),
          ],
        ),
        body: Column(
          children: [
            if (_errorMessage == null && _loadingProgress < 100)
              LinearProgressIndicator(
                value: _loadingProgress == 0 ? null : _loadingProgress / 100.0,
                minHeight: 3,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshCompleter = Completer<void>();
                  _refresh();
                  try {
                    await _refreshCompleter!.future.timeout(
                      const Duration(seconds: 12),
                    );
                  } catch (_) {
                  } finally {
                    _refreshCompleter = null;
                  }
                },
                color: Theme.of(context).primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: _errorMessage != null
                        ? _buildErrorWidget()
                        : WebViewWidget(controller: _controller),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds error UI when WebView fails to load content.
  ///
  /// Provides:
  /// • Error icon and message
  /// • Go back navigation button
  /// • Retry loading button
  Widget _buildErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Icon(
                HugeIcons.strokeRoundedAlertCircle,
                color: Colors.red,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to Load Page',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An error occurred while loading the page.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    HugeIcons.strokeRoundedArrowLeft01,
                    size: 16,
                  ),
                  label: Text(
                    'Go Back',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    side: BorderSide(
                      color: isDark ? Colors.grey[600]! : Colors.grey[300]!,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(HugeIcons.strokeRoundedRefresh, size: 16),
                  label: Text(
                    'Try Again',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
