/// Domain model representing a single Work Order (mrp.workorder in Odoo).
///
/// This class is used to:
/// - Parse JSON responses from Odoo RPC calls
/// - Display work orders in lists, cards, or grouped views
/// - Show real-time timers, status, and duration formatting
/// - Pass data to detail screens or action handlers
class WorkOrder {
  final int id;
  final String operation;
  final String? mo;
  final String workCenter;
  final int workCenterId;
  final String product;
  final double quantity;
  final double expectedDuration;
  final double realDuration;
  final String status;

  WorkOrder({
    required this.id,
    required this.operation,
    this.mo,
    required this.workCenter,
    required this.workCenterId,
    required this.product,
    required this.quantity,
    required this.expectedDuration,
    required this.realDuration,
    required this.status,
  });

  /// Factory constructor to safely parse Odoo JSON response into a WorkOrder.
  ///
  /// Handles:
  /// - Nested many2one fields (production_id, workcenter_id, product_id)
  /// - Safe fallback values (0, '', null) when fields are missing/null
  /// - Duration fields kept as double (hours)
  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      id: json['id'] ?? 0,
      operation: json['name'] ?? '',
      mo: json['production_id'][1] ?? '',
      workCenter: json['workcenter_id'][1] ?? '',
      workCenterId: json['workcenter_id'][0] ?? 0,
      product: json['product_id'][1] ?? '',
      quantity: (json['quantity'] ?? 0).toDouble(),
      expectedDuration: json['duration_expected'] ?? '',
      realDuration: json['duration'] ?? '',
      status: json['state'] ?? '',
    );
  }

  /// Returns formatted duration string in HH:mm format.
  ///
  /// Converts realDuration (hours) to total minutes, then to hours:minutes.
  /// Returns '00:00' if duration is null or zero.
  String get formattedDuration {
    if (realDuration == null || realDuration == 0.0) return '00:00';
    final totalMinutes = (realDuration! * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Returns formatted expected duration string in HH:mm format.
  ///
  /// Similar to `formattedDuration`, but uses expectedDuration.
  String get formattedExpectedDuration {
    if (expectedDuration == null || expectedDuration == 0.0) return '00:00';
    final totalMinutes = (expectedDuration! * 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }
}
