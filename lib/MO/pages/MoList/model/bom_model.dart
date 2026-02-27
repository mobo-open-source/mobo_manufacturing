/// Represents a single line/item in a Bill of Materials (BOM).
///
/// Each line describes one component/product that is consumed/produced
/// in a manufacturing process, typically used in Manufacturing Orders (MO).
class BomLineModel {
  final int productId;
  final String productName;
  final double toConsume;

  BomLineModel({
    required this.productId,
    required this.productName,
    required this.toConsume,
  });

  /// Factory constructor to create a BomLineModel from Odoo JSON response
  ///
  /// Expects Odoo-style nested list for `product_id` field: [id, display_name]
  factory BomLineModel.fromJson(Map<String, dynamic> json) {
    final product = json['product_id'] as List?;
    return BomLineModel(
      productId: product != null ? product[0] : 0,
      productName: product != null ? product[1] : '',
      toConsume: (json['product_qty'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Converts this BOM line model back to a JSON-compatible map
  ///
  /// Useful for sending data back to backend or serializing
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'to_consume': toConsume,
    };
  }
}
