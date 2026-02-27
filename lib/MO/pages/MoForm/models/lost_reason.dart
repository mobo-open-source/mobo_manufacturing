/// Represents a reason for productivity loss or work order blocking in manufacturing.
///
/// In Odoo MRP, these records come from the model `mrp.workcenter.productivity.loss`
/// and are used when a work order is paused/blocked (e.g. "Machine breakdown",
/// "No materials", "Operator absent").
///
/// This class keeps only the essential fields needed for selection/display:
/// - `id`: unique identifier
/// - `name`: human-readable reason text
class LostReason {
  final int id;
  final String name;

  LostReason({required this.id, required this.name});

  /// Creates a `LostReason` from an Odoo JSON map.
  ///
  /// Expected structure:
  /// ```json
  /// {"id": 42, "name": "No components available"}
  /// ```
  factory LostReason.fromJson(Map<String, dynamic> json) {
    return LostReason(id: json['id'] ?? 0, name: json['name'] ?? '');
  }

  /// Converts this instance to a simple JSON-compatible map.
  ///
  /// Useful for dropdown items, BLoC events, or serialization.
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
