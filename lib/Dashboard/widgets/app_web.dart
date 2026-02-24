import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/widgets/snackbar.dart';

/// Displays a web page inside the app using WebView.
///
/// Features:
/// • Loads external URLs inside app
/// • Shows loading indicator while page loads
/// • Handles web errors with snackbar feedback
/// • Supports optional page title
class InAppWebPage extends StatefulWidget {
  final Uri url;
  final String? title;

  const InAppWebPage({super.key, required this.url, this.title});

  @override
  State<InAppWebPage> createState() => _InAppWebPageState();
}

class _InAppWebPageState extends State<InAppWebPage> {
  bool isLoading = true;
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    /// Initializes WebView controller and loads the requested URL.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.url)
      ..setNavigationDelegate(
        NavigationDelegate(
          /// Triggered when page finishes loading.
          onPageFinished: (_) {
            if (mounted) setState(() => isLoading = false);
          },

          /// Triggered when web resource fails to load.
          onWebResourceError: (error) {
            if (mounted) {
              CustomSnackbar.showError(
                context,
                'Failed to load page: ${error.description}',
              );
            }
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title ?? 'Web Page',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),

        /// Custom back button.
        leading: IconButton(
          icon: Icon(
            HugeIcons.strokeRoundedArrowLeft01,
            color: isDark ? Colors.white : Colors.black,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          /// Main WebView content.
          WebViewWidget(controller: _controller),

          /// Loading overlay while page is loading.
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
