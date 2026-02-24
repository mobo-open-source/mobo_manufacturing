import 'package:flutter/material.dart';

/// Builds a colored status chip for **stock move** states (component/raw material moves in a Manufacturing Order).
///
/// Displays a pill-shaped indicator with descriptive text and appropriate color based on the move status.
/// Common statuses include: draft, waiting, confirmed, partially_available, done, assigned, cancel.
///
/// This chip is typically used in tables or lists showing component availability and progress
/// (e.g. in MO overview material table or product move page).
///
/// @param status The raw status string from Odoo (e.g. 'confirmed', 'done', 'partially_available')
/// @param isDark Whether dark theme is active (affects text color for readability)
Widget buildMoveStatus(String? status, isDark) {
  String statusText = '';
  Color statusColor = Colors.grey;

  // ─── Map stock move status to display text and color ────────────────────
  switch ((status ?? '').toLowerCase()) {
    case 'draft':
      statusText = 'New';
      statusColor = Colors.teal;
      break;
    case 'waiting':
      statusText = 'Waiting Another Move';
      statusColor = Colors.amber;
      break;
    case 'confirmed':
      statusText = 'Waiting Availability';
      statusColor = Colors.blue;
      break;
    case 'partially_available':
      statusText = 'Partially Available';
      statusColor = Colors.orange;
      break;
    case 'done':
      statusText = 'Done';
      statusColor = Colors.green;
      break;
    case 'assigned':
      statusText = 'Available';
      statusColor = Colors.blue;
      break;
    case 'cancel':
      statusText = 'Cancelled';
      statusColor = Colors.redAccent;
      break;
    default:
      statusText = (status ?? 'UNKNOWN').toUpperCase();
      statusColor = Colors.grey;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: statusColor,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      statusText,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
