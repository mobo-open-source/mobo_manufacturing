/// Simple model class representing a product record from Odoo (`product.product` model).
///
/// Used throughout the app for:
/// • Dropdown selections (components, produced item, scrap products, etc.)
/// • Displaying product names in tables/lists
/// • Passing product references in events and API calls
///
/// Keeps only the minimal fields needed: `id` and `name`.
class Product {
  final int id;
  final String name;

  Product({required this.id, required this.name});

  /// Factory constructor that creates a `Product` from an Odoo JSON response.
  ///
  /// Expected minimal JSON structure:
  /// ```json
  /// {
  ///   "id": 123,
  ///   "name": "Widget A"
  /// }
  /// ```
  ///
  /// - Uses `id` directly
  /// - Uses `name` directly
  /// - Falls back to 0 or empty string if fields are missing
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(id: json['id'] ?? 0, name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
