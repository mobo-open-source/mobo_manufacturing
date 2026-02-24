/// Model class representing a single stock move in a Manufacturing Order (MO).
///
/// In Odoo MRP, stock moves track the movement of materials/components:
/// - From raw material locations → production location (consumption)
/// - From production location → finished goods location (production)
///
/// This class captures the essential fields needed for:
/// - Displaying component lists
/// - Tracking consumption (toConsume, picked)
/// - Showing traceability (locations, lots, quantities)
/// - Calculating costs and availability
class StockMove {
  final int id;
  final List<dynamic>? productId;
  final List<dynamic>? orderFinishedLotId;
  final List<dynamic>? locationId;
  final List<dynamic>? locationDestId;
  final List<dynamic>? byproductId;
  final double? toConsume;
  final double? quantity;
  final double? availability;
  late bool picked;
  final double? productVirtualAvailable;
  final double? priceUnit;
  final String? productType;

  StockMove({
    required this.id,
    this.productId,
    this.orderFinishedLotId,
    this.locationId,
    this.locationDestId,
    this.byproductId,
    this.toConsume,
    this.quantity,
    this.availability,
    required this.picked,
    this.productVirtualAvailable,
    this.priceUnit,
    this.productType,
  });

  /// Factory constructor that safely parses an Odoo JSON response into a `StockMove`.
  ///
  /// Handles:
  /// - Missing/null fields with safe defaults
  /// - Type conversion (int → double, string → double, etc.)
  /// - Many2one fields stored as lists `[id, name]`
  /// - `picked` field (boolean or 0/1 from Odoo)
  factory StockMove.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return StockMove(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      productId: (json['product_id'] is List)
          ? List<dynamic>.from(json['product_id'])
          : null,
      orderFinishedLotId: (json['order_finished_lot_id'] is List)
          ? List<dynamic>.from(json['order_finished_lot_id'])
          : null,
      locationId: (json['location_id'] is List)
          ? List<dynamic>.from(json['location_id'])
          : null,
      locationDestId: (json['location_dest_id'] is List)
          ? List<dynamic>.from(json['location_dest_id'])
          : null,
      byproductId: (json['byproduct_id'] is List)
          ? List<dynamic>.from(json['byproduct_id'])
          : null,
      toConsume: parseDouble(json['product_uom_qty']),
      quantity: parseDouble(json['quantity']),
      availability: parseDouble(json['availability']),
      priceUnit: parseDouble(json['price_unit']),
      productVirtualAvailable: parseDouble(json['product_virtual_available']),
      picked: (json['picked'] == true || json['picked'] == 1),
      productType: json['product_type']?.toString() ?? '',
    );
  }

  /// Converts this `StockMove` instance back to a JSON-like map.
  ///
  /// Useful for:
  /// - Sending updates back to Odoo (write operations)
  /// - Passing data to UI components or BLoC events
  /// - Serialization/debugging
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'order_finished_lot_id': orderFinishedLotId,
      'location_id': locationId,
      'location_dest_id': locationDestId,
      'byproduct_id': byproductId,
      'product_uom_qty': toConsume,
      'quantity': quantity,
      'availability': availability,
      'price_unit': priceUnit,
      'product_virtual_available': productVirtualAvailable,
      'picked': picked,
      'product_type': productType,
    };
  }
}
