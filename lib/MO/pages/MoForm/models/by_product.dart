/// Model class representing a "By-Product" record in a Manufacturing Order context.
///
/// In Odoo MRP (Manufacturing), by-products are additional products that are produced
/// as a side effect of manufacturing the main product (e.g. scraps, co-products).
///
/// This class stores minimal data:
/// - `id`: ID of the by-product move or record
/// - `product`: Display name of the by-product (usually from `product_id[1]`)
///
/// Used mainly for dropdowns, lists, or display in MO detail/traceability screens.
class ByProduct {
  final int id;
  final String product;

  ByProduct({required this.id, required this.product});

  /// Factory constructor that creates a `ByProduct` from an Odoo JSON response.
  ///
  /// Expected JSON structure (partial):
  /// ```json
  /// {
  ///   "id": 123,
  ///   "product_id": [456, "By-Product Name"]
  /// }
  /// ```
  ///
  /// - Uses `id` directly
  /// - Extracts `product` name from `product_id[1]` (display name of many2one field)
  /// - Falls back to 0 or empty string if fields are missing/null
  factory ByProduct.fromJson(Map<String, dynamic> json) {
    return ByProduct(id: json['id'] ?? 0, product: json['product_id'][1] ?? '');
  }

  /// Converts this `ByProduct` instance back to a simple JSON-like map.
  ///
  /// Useful when:
  /// - Sending data to UI dropdowns or selection widgets
  /// - Passing to BLoC events
  /// - Serializing for logging/debugging
  Map<String, dynamic> toJson() {
    return {'id': id, 'product': product};
  }
}
