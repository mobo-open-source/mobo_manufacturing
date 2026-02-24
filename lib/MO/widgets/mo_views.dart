import 'package:flutter/material.dart';
import '../../globals.dart';

/// Horizontal bar with circular icon buttons to switch between different MO views:
/// List, Kanban, Calendar, Graph.
///
/// Tapping an icon updates the internal selected state and calls the `onSelected` callback
/// with the chosen view key ('list', 'kanban', 'calendar', 'graph').
class MoViews extends StatefulWidget {
  final Function(String?) onSelected;

  const MoViews({super.key, required this.onSelected});

  @override
  State<MoViews> createState() => _MoViewsState();
}

class _MoViewsState extends State<MoViews> {
  String? _selectedView = "list";

  // Available view options with icons and labels
  final List<Map<String, dynamic>> _views = [
    {"key": "list", "icon": Icons.list, "label": "List"},
    {"key": "kanban", "icon": Icons.view_kanban, "label": "Kanban"},
    {"key": "calendar", "icon": Icons.calendar_today, "label": "Calendar"},
    {"key": "graph", "icon": Icons.bar_chart, "label": "Graph"},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _views.map((view) {
          final isSelected = _selectedView == view["key"];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedView = view["key"]);
              widget.onSelected(view["key"]);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isSelected
                      ? (isDark ? Colors.grey.shade700 : AppStyle.primaryColor)
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                  child: Icon(
                    view["icon"],
                    color: isSelected ? Colors.white : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  view["label"],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? (isDark ? Colors.white : AppStyle.primaryColor)
                        : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
