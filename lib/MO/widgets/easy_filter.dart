import 'package:flutter/material.dart';
import '../../globals.dart';

/// Horizontal filter bar for quick status filtering and view mode switching.
///
/// Contains:
/// - A dropdown chip to switch between List / Kanban / Calendar / Graph views
/// - Filter chips for high-level inventory stages (Raw Materials, WIP, Finished Goods)
///
/// Responsive font size based on screen width.
class EasyFilterBar extends StatelessWidget {
  final String? selectedStatus;
  final Function(String?) onSelected;
  final String selectedView;
  final Function(String) onViewChanged;

  const EasyFilterBar({
    super.key,
    required this.selectedStatus,
    required this.onSelected,
    required this.selectedView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statuses = ["Raw Materials", "Work in Progress", "Finished Goods"];

    // Responsive font sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    double fontSize;
    if (screenWidth < 450) {
      fontSize = 11;
    } else if (screenWidth < 600) {
      fontSize = 13;
    } else if (screenWidth < 900) {
      fontSize = 15;
    } else {
      fontSize = 17;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // View mode selector (dropdown chip)
            _ViewDropdownChip(
              theme: theme,
              fontSize: fontSize,
              selectedView: selectedView,
              onSelected: onViewChanged,
            ),
            const SizedBox(width: 12),

            // Status filter chips
            for (int i = 0; i < statuses.length; i++) ...[
              _FilterChip(
                label: statuses[i],
                isSelected: selectedStatus == statuses[i],
                fontSize: fontSize,
                theme: theme,
                onTap: () => onSelected(
                  selectedStatus == statuses[i] ? null : statuses[i],
                ),
              ),
              if (i != statuses.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable chip widget for status filters (toggle on/off)
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final double fontSize;
  final ThemeData theme;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.fontSize,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? Colors.grey[800] : Colors.black)
            : Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isSelected ? Colors.black : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown chip for switching between list, kanban, calendar, and graph views
class _ViewDropdownChip extends StatelessWidget {
  final ThemeData theme;
  final double fontSize;
  final String selectedView;
  final Function(String) onSelected;

  const _ViewDropdownChip({
    required this.theme,
    required this.fontSize,
    required this.selectedView,
    required this.onSelected,
  });

  /// Human-readable label for each view mode
  String _labelFor(String v) {
    switch (v) {
      case 'kanban':
        return 'Kanban';
      case 'calendar':
        return 'Calendar';
      case 'graph':
        return 'Graph';
      case 'list':
      default:
        return 'List';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      onSelected: onSelected,
      color: isDark ? Colors.grey[800] : Colors.white,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'list',
          child: Text(
            'List',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        PopupMenuItem(
          value: 'kanban',
          child: Text(
            'Kanban',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        PopupMenuItem(
          value: 'calendar',
          child: Text(
            'Calendar',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        PopupMenuItem(
          value: 'graph',
          child: Text(
            'Graph',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white : AppStyle.primaryColor,
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labelFor(selectedView),
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
