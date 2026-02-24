/// Model representing a single Work Order (operation) in a Manufacturing Order (MO).
///
/// In Odoo MRP, work orders are the individual operations/steps needed to produce
/// the finished product. Each work order is tied to a work center and has:
/// - planned/expected duration
/// - actual duration (tracked over time)
/// - cost per hour
/// - current state (pending, ready, in progress, done, etc.)
class MoWorkOrder {
  final int id;
  final String? operation;
  final List<dynamic>? workCenterId;
  final double? duration;
  final double? durationExpected;
  final double? costs_hour;
  final String? state;

  MoWorkOrder({
    required this.id,
    this.operation,
    this.workCenterId,
    this.duration,
    this.durationExpected,
    this.costs_hour,
    this.state,
  });

  /// Creates a `MoWorkOrder` from an Odoo JSON response.
  factory MoWorkOrder.fromJson(Map<String, dynamic> json) {
    return MoWorkOrder(
      id: json['id'] is int ? json['id'] : 0,
      operation: json['name']?.toString(),
      workCenterId: json['workcenter_id'] as List<dynamic>?,
      duration: (json['duration'] ?? 0).toDouble(),
      durationExpected: (json['duration_expected'] ?? 0).toDouble(),
      costs_hour: (json['costs_hour'] ?? 0).toDouble(),
      state: json['state']?.toString(),
    );
  }

  /// Converts this instance to a simple map (useful for serialization or events).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'operation': operation,
      'workcenter_id': workCenterId,
      'duration': duration,
      'duration_expected': durationExpected,
      'costs_hour': costs_hour,
      'state': state,
    };
  }

  // ────────────────────────────────────────────────
  // Convenience getters
  // ────────────────────────────────────────────────

  /// Display name of the assigned work center (or '-' if missing)
  String get workCenterName {
    if (workCenterId != null && workCenterId!.length > 1) {
      return workCenterId![1].toString();
    }
    return '-';
  }

  /// Formats actual duration as HH:mm (e.g. "02:45")
  String get formattedDuration {
    if (duration == null || duration == 0.0) return '00:00';
    final totalMinutes = (duration! * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Formats expected duration as HH:mm
  String get formattedExpectedDuration {
    if (durationExpected == null || durationExpected == 0.0) return '00:00';
    final totalMinutes = (durationExpected! * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}
