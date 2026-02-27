import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../globals.dart';

/// Base layout wrapper used for login-related screens.
///
/// Provides:
/// • Background image with theme overlay
/// • App branding header
/// • Centered responsive content container
/// • Scroll-safe layout for small screens
/// • Optional back button support
class LoginLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? backButton;

  /// Creates a login layout container.
  ///
  /// Parameters:
  /// • title → Main heading text
  /// • subtitle → Supporting description text
  /// • child → Form or content widget
  /// • backButton → Optional positioned back button widget
  const LoginLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.backButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[950] : Colors.grey[50],
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    isDark
                        ? Colors.black.withOpacity(1)
                        : Colors.white.withOpacity(1),
                    BlendMode.dstATop,
                  ),
                  onError: (exception, stackTrace) {},
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
                    height: 32,
                    width: 32,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.precision_manufacturing,
                        color: AppStyle.primaryColor,
                        size: 20,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
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

          SafeArea(
            child: LayoutBuilder(
              builder: (context, viewportConstraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 0.0,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: viewportConstraints.maxHeight,
                    ),
                    child: Align(
                      alignment: const Alignment(0, -0.05),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            _buildSignInHeader(),
                            const SizedBox(height: 40),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  inputDecorationTheme: Theme.of(context)
                                      .inputDecorationTheme
                                      .copyWith(
                                        errorStyle: const TextStyle(
                                          color: Colors.white,
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.red[900]!,
                                            width: 1.0,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.white,
                                            width: 1.5,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                ),
                                child: child,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (backButton != null) backButton!,
        ],
      ),
    );
  }

  /// Builds the login header section containing title and subtitle text.
  Widget _buildSignInHeader() {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: 32,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Styled text form field used across login screens.
///
/// Supports validation, error state display, prefix/suffix icons,
/// focus control, and autovalidation.
class LoginTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Creates a login text input field.
  ///
  /// Parameters:
  /// • controller → Text editing controller
  /// • hint → Placeholder text
  /// • prefixIcon → Leading icon
  /// • keyboardType → Input keyboard type
  /// • obscureText → Hides text (e.g., password)
  /// • enabled → Field interaction state
  /// • validator → Validation function
  /// • suffixIcon → Optional trailing icon
  /// • hasError → Displays error indicator icon
  /// • onChanged → Value change callback
  /// • autovalidateMode → Auto validation behavior
  /// • focusNode → External focus control
  /// • autofocus → Auto focus on load
  const LoginTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.validator,
    this.suffixIcon,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      cursorColor: Colors.black,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Colors.black,
      ),
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Colors.black.withOpacity(.4),
        ),
        prefixIcon: Icon(prefixIcon, size: 20),
        prefixIconColor: MaterialStateColor.resolveWith(
          (states) => states.contains(MaterialState.disabled)
              ? Colors.black26
              : Colors.black54,
        ),
        suffixIcon: hasError
            ? Icon(Icons.error_outline, color: Colors.red, size: 20)
            : suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }
}

/// Styled dropdown selection field for login forms.
///
/// Automatically removes duplicate items and safely validates selected value.
class LoginDropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;
  final bool hasError;
  final AutovalidateMode? autovalidateMode;

  /// Creates a login dropdown selection field.
  ///
  /// Parameters:
  /// • hint → Placeholder text
  /// • value → Selected value
  /// • items → Dropdown option list
  /// • onChanged → Selection callback
  /// • validator → Validation function
  /// • hasError → Error indicator state
  /// • autovalidateMode → Auto validation behavior
  const LoginDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.validator,
    this.hasError = false,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final uniqueItems = items.toSet().toList();
    final safeValue = uniqueItems.contains(value) ? value : null;
    final bool isEnabled = onChanged != null;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            elevation: MaterialStateProperty.all(8),
            backgroundColor: MaterialStateProperty.all(Colors.white),
            surfaceTintColor: MaterialStateProperty.all(Colors.transparent),
          ),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        items: uniqueItems.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator,
        autovalidateMode: autovalidateMode,
        menuMaxHeight: 200,
        borderRadius: BorderRadius.circular(16),
        dropdownColor: Colors.white,
        elevation: 8,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isEnabled ? Colors.black54 : Colors.black26,
          size: 24,
        ),
        iconSize: 24,
        isExpanded: true,
        hint: Text(
          hint,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black.withOpacity(.4),
          ),
        ),
        decoration: InputDecoration(
          enabled: isEnabled,
          prefixIcon: Icon(HugeIcons.strokeRoundedDatabase, size: 20),
          prefixIconColor: MaterialStateColor.resolveWith(
            (states) => states.contains(MaterialState.disabled)
                ? Colors.black26
                : Colors.black54,
          ),
          suffixIcon: (hasError && (safeValue == null || safeValue.isEmpty))
              ? Icon(
                  HugeIcons.strokeRoundedAlertCircle,
                  color: Colors.red[900],
                  size: 20,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

/// Animated error message display used in login screens.
///
/// Shows error text with smooth transition and icon indicator.
class LoginErrorDisplay extends StatelessWidget {
  final String? error;

  /// Creates an animated login error display.
  ///
  /// Parameters:
  /// • error → Error message to display (null hides widget)
  const LoginErrorDisplay({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: error != null
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      HugeIcons.strokeRoundedAlertCircle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// URL input field with protocol selector and loading indicator.
///
/// Supports HTTP/HTTPS switching, validation, and async loading feedback.
class LoginUrlTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final bool hasError;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final bool autofocus;
  final String selectedProtocol;
  final ValueChanged<String>? onProtocolChanged;
  final bool isLoading;

  /// Creates a URL input field with protocol selector.
  ///
  /// Parameters:
  /// • controller → Text editing controller
  /// • hint → Placeholder text
  /// • prefixIcon → Leading icon
  /// • enabled → Field interaction state
  /// • validator → Validation function
  /// • hasError → Error indicator state
  /// • onChanged → Value change callback
  /// • autovalidateMode → Auto validation behavior
  /// • focusNode → External focus control
  /// • autofocus → Auto focus on load
  /// • selectedProtocol → Selected protocol prefix
  /// • onProtocolChanged → Protocol change callback
  /// • isLoading → Shows loading indicator
  const LoginUrlTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.enabled = true,
    this.validator,
    this.hasError = false,
    this.onChanged,
    this.autovalidateMode,
    this.focusNode,
    this.autofocus = false,
    this.selectedProtocol = 'https://',
    this.onProtocolChanged,
    this.isLoading = false,
  });

  @override
  State<LoginUrlTextField> createState() => _LoginUrlTextFieldState();
}

class _LoginUrlTextFieldState extends State<LoginUrlTextField> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          cursorColor: Colors.black,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
          controller: widget.controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          validator: widget.validator,
          autovalidateMode: widget.autovalidateMode,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black.withOpacity(.4),
            ),
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: widget.enabled ? Colors.black54 : Colors.black26,
                  ),
                ),
                Container(
                  height: 48,
                  width: 72,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Colors.black.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    enabled: widget.enabled,
                    initialValue: widget.selectedProtocol,
                    padding: EdgeInsets.zero,
                    position: PopupMenuPosition.under,
                    color: Colors.white,
                    constraints: const BoxConstraints(
                      minWidth: 72,
                      maxWidth: 72,
                    ),
                    itemBuilder: (context) => ['http://', 'https://']
                        .map(
                          (p) => PopupMenuItem<String>(
                            value: p,
                            child: Text(
                              p,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onSelected: (value) =>
                        widget.onProtocolChanged?.call(value),
                    child: Container(
                      height: 48,
                      width: 85,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              widget.selectedProtocol,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.enabled
                                    ? Colors.black
                                    : Colors.black26,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                            color: widget.enabled
                                ? Colors.black54
                                : Colors.black26,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.black54,
                        ),
                      ),
                    ),
                  ),
                if (widget.hasError && !widget.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.only(
              left: 0,
              right: 20,
              top: 16,
              bottom: 16,
            ),
          ),
        ),
      ],
    );
  }
}

/// Primary action button used in login flows.
///
/// Handles loading state, disabled state, and custom loading widget support.
class LoginButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? loadingWidget;
  final bool isEnabled;

  /// Creates a login action button.
  ///
  /// Parameters:
  /// • text → Button label text
  /// • onPressed → Tap callback
  /// • isLoading → Loading state flag
  /// • loadingWidget → Optional loading widget
  /// • isEnabled → Manual enable/disable control
  const LoginButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.loadingWidget,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = isEnabled && !isLoading && onPressed != null;

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isInteractive ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isInteractive
              ? Colors.black
              : Colors.black.withOpacity(0.3),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black.withOpacity(0.2),
          disabledForegroundColor: Colors.white,
          overlayColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading && loadingWidget != null
            ? loadingWidget!
            : Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
