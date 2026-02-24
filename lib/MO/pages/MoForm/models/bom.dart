/// Model class representing a Bill of Materials (BOM) record from Odoo.
///
/// A BOM defines the components and quantities required to manufacture a product.
/// In this app, only the minimal fields (`id` and `name`) are stored for display
/// and selection purposes (usually shown in dropdowns or lists).
///
/// The `name` field typically comes from `product_tmpl_id[1]` (the product template name).
class Bom {
  final int id;
  final String name;

  Bom({required this.id, required this.name});

  /// Factory constructor that creates a `Bom` from an Odoo JSON response.
  ///
  /// Expected JSON structure (partial):
  /// ```json
  /// {
  ///   "id": 123,
  ///   "product_tmpl_id": [456, "Product Name"]
  /// }
  /// ```
  ///
  /// - Uses `id` directly
  /// - Extracts `name` from `product_tmpl_id[1]` (many2one display name)
  /// - Falls back to empty string or 0 if fields are missing
  factory Bom.fromJson(Map<String, dynamic> json) {
    return Bom(id: json['id'] ?? 0, name: json['product_tmpl_id'][1] ?? '');
  }

  /// Converts this `Bom` instance back to a simple JSON-like map.
  ///
  /// Useful when sending data back to UI dropdowns, BLoC events,
  /// or when serializing for debugging/logging.
  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
