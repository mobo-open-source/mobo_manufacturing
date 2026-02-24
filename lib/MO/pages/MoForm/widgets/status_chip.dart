import 'package:flutter/material.dart';

/// Builds a status indicator chip for **work order** (WO) states.
///
/// Displays a colored pill with descriptive text based on the work order status.
/// Common statuses include: pending, waiting, ready, progress, done, cancel.
///
/// Used primarily in tables/lists showing work orders (e.g., material table in overview).
///
/// @param status The raw status string from Odoo (e.g. 'progress', 'done')
/// @param isDark Whether dark theme is active (affects background/text contrast)
Widget buildStatusChip(String? status, isDark) {
  String statusText = '';
  Color statusColor = Colors.grey;

  // ─── Map status to display text and color ───────────────────────────────
  switch ((status ?? '').toLowerCase()) {
    case 'pending':
      statusText = 'Waiting for another WO';
      statusColor = Colors.teal;
      break;
    case 'waiting':
      statusText = 'Waiting for Components';
      statusColor = Colors.amber;
      break;
    case 'ready':
      statusText = 'Ready';
      statusColor = Colors.blue;
      break;
    case 'progress':
      statusText = 'In Progress';
      statusColor = Colors.orange;
      break;
    case 'done':
      statusText = 'Finished';
      statusColor = Colors.green;
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
      color: isDark ? Colors.grey[800] : statusColor,
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

/// Builds a status indicator chip for **Manufacturing Order (MRP)** states.
///
/// Displays a colored pill with standard MRP status text.
/// Common states include: draft, confirmed, progress, to_close, done, cancel.
///
/// Used mainly in header cards or summary sections of MO detail/overview pages.
///
/// @param status The raw state string from Odoo (e.g. 'confirmed', 'done')
/// @param isDark Whether dark theme is active (affects background/text contrast)
Widget buildStatusMrp(String? status, isDark) {
  String statusText = '';
  Color statusColor = Colors.grey;

  // ─── Map MRP state to display text and color ────────────────────────────
  switch ((status ?? '').toLowerCase()) {
    case 'draft':
      statusText = 'Draft';
      statusColor = Colors.blue;
      break;
    case 'confirmed':
      statusText = 'Confirmed';
      statusColor = Colors.teal;
      break;
    case 'progress':
      statusText = 'In Progress';
      statusColor = Colors.orange;
      break;
    case 'to_close':
      statusText = 'To Close';
      statusColor = Colors.green;
      break;
    case 'done':
      statusText = 'Done';
      statusColor = Colors.green[500]!;
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
      color: isDark ? Colors.grey[800] : statusColor,
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
