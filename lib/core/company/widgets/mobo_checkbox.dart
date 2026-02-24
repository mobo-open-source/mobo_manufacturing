import 'package:flutter/material.dart';

import '../../../globals.dart';

/// Custom styled checkbox used across Mobo UI.
///
/// Features:
/// • Supports hover effect (desktop/web)
/// • Dark / Light theme adaptation
/// • Custom size and border radius
/// • Disabled state when onChanged is null
class MoboCheckbox extends StatefulWidget {
  /// Current checkbox value.
  final bool value;

  /// Callback triggered when checkbox value changes.
  /// If null → checkbox becomes disabled.
  final ValueChanged<bool>? onChanged;

  /// Checkbox width & height.
  final double size;

  /// Border radius of checkbox container.
  final double radius;

  const MoboCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 22,
    this.radius = 6,
  });

  @override
  State<MoboCheckbox> createState() => _MoboCheckboxState();
}

class _MoboCheckboxState extends State<MoboCheckbox> {
  /// Tracks hover state for hover background effect.
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = AppStyle.primaryColor;

    /// Checkbox disabled when no change handler provided.
    final isDisabled = widget.onChanged == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      /// Enables hover visual feedback (mainly web / desktop)
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        /// Toggle checkbox value when tapped (if enabled)
        onTap: isDisabled ? null : () => widget.onChanged!(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),

            /// Border adapts to theme
            border: Border.all(
              color: isDark ? Colors.white : primary,
              width: 2,
            ),

            /// Background logic:
            /// • Selected → filled
            /// • Hover → light fill preview
            /// • Default → transparent
            color: widget.value
                ? (isDark ? Colors.white : primary)
                : (_hovering
                      ? (isDark ? Colors.white : primary.withOpacity(0.10))
                      : Colors.transparent),
          ),

          /// Show check icon only when selected
          child: widget.value
              ? Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: isDark ? Colors.black : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
