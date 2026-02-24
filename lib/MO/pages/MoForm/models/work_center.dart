/// Model class representing a Work Center (machine, production line, assembly station, etc.)
/// in Odoo's Manufacturing module (`mrp.workcenter` model).
///
/// Work centers are the resources where operations (work orders) are performed.
/// This class keeps only the minimal fields needed for display and selection:
/// - `id`: unique identifier
/// - `name`: human-readable name (usually shown in dropdowns, tables, etc.)
///
/// Commonly used when:
/// • Assigning operations to work centers
/// • Showing work center names in work order lists
/// • Filtering or grouping production data
class WorkCenter {
  final int id;
  final String name;

  WorkCenter({required this.id, required this.name});

  /// Factory constructor that creates a `WorkCenter` from an Odoo JSON response.
  ///
  /// Expected minimal JSON structure:
  /// ```json
  /// {
  ///   "id": 15,
  ///   "name": "Painting Station"
  /// }
  /// ```
  ///
  /// - Uses `id` directly
  /// - Uses `name` directly
  /// - Falls back to 0 or empty string if fields are missing/null
  factory WorkCenter.fromJson(Map<String, dynamic> json) {
    return WorkCenter(id: json['id'] ?? 0, name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
