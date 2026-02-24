/// Represents a single reason for lost time.
///
/// Used in:
/// - Blocking a work order (mrp.workorder → productivity loss reason)
/// - Displaying reason dropdowns in UI
/// - Sending reason ID to Odoo when blocking/pausing
class LostWoReason {
  final int id;
  final String name;

  LostWoReason({required this.id, required this.name});

  /// Factory constructor to safely parse from Odoo JSON response.
  ///
  /// Provides fallback values (id: 0, name: '') if fields are missing/null.
  factory LostWoReason.fromJson(Map<String, dynamic> json) {
    return LostWoReason(id: json['id'] ?? 0, name: json['name'] ?? '');
  }

  /// Converts this model back to a JSON-compatible map.
  ///
  /// Useful for sending data back to Odoo or serializing for storage.
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
