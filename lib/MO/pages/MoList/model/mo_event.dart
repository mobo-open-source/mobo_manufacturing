import 'dart:convert';

import 'package:flutter/material.dart';

/// Represents a scheduled Manufacturing Order (MO) event for calendar display.
///
/// Used primarily with `TableCalendar` to show MOs as appointments/events
/// on specific dates. The `notes` field typically stores the raw JSON of the MO
/// for easy access to detailed information when the event is tapped.
class MOEvent {
  final DateTime startTime;
  final DateTime endTime;
  final String? subject;
  final String? notes;
  final Color? color;

  /// Creates a new calendar event for a Manufacturing Order
  MOEvent({
    required this.startTime,
    required this.endTime,
    this.subject,
    this.notes,
    this.color,
  });

  /// Lazily parses and returns the original MO data map stored in `notes`
  ///
  /// Returns an empty map if:
  /// - `notes` is null or empty
  /// - JSON decoding fails
  /// - Any other parsing error occurs
  ///
  /// This getter provides convenient access to full MO details
  /// (product, qty, state, etc.) without duplicating storage.
  Map<String, dynamic> get parsedItem {
    if (notes == null || notes!.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(notes!));
    } catch (e) {
      return {};
    }
  }
}