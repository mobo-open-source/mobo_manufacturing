/// Domain model representing a single Scrap record (stock.scrap in Odoo).
///
/// This class is used to:
/// - Parse JSON responses from Odoo RPC calls
/// - Display scrap items in lists/cards
/// - Pass data to detail screens
///
/// Handles Odoo-specific nested list format for many2one fields (e.g. product_id: [id, name]).
class ScrapItem {
  final String id;
  final String name;
  final String product;
  final String location;
  final String scrapLocation;
  final String manufacturingOrder;
  final String mo;
  final bool origin;
  final String company;
  final String date;
  final int quantity;
  final String status;
  final bool replenish;

  ScrapItem({
    required this.id,
    required this.name,
    required this.product,
    required this.location,
    required this.scrapLocation,
    required this.manufacturingOrder,
    required this.mo,
    required this.origin,
    required this.company,
    required this.date,
    required this.quantity,
    required this.status,
    required this.replenish,
  });

  /// Factory constructor to safely parse Odoo JSON response into a ScrapItem.
  ///
  /// Handles:
  /// - Nested many2one fields (product_id, location_id, etc.) → extracts display name
  /// - Safe fallback values ('', 0, false) when fields are missing/null
  /// - Date string preservation (no parsing — kept as-is for display)
  /// - Boolean parsing from various formats
  factory ScrapItem.fromJson(Map<String, dynamic> json) {
    String productName = '';
    if (json['product_id'] != null &&
        json['product_id'] is List &&
        json['product_id'].length > 1) {
      final val = json['product_id'][1];
      if (val is String) {
        productName = val;
      } else if (val is List && val.isNotEmpty) {
        productName = val[0].toString();
      }
    }

    String locationName = '';
    if (json['location_id'] != null &&
        json['location_id'] is List &&
        json['location_id'].length > 1) {
      final val = json['location_id'][1];
      if (val is String) {
        locationName = val;
      } else if (val is List && val.isNotEmpty) {
        locationName = val[0].toString();
      }
    }

    String scrapLocationName = '';
    if (json['scrap_location_id'] != null &&
        json['scrap_location_id'] is List &&
        json['scrap_location_id'].length > 1) {
      final val = json['scrap_location_id'][1];
      if (val is String) {
        scrapLocationName = val;
      } else if (val is List && val.isNotEmpty) {
        scrapLocationName = val[0].toString();
      }
    }

    String moName = '';
    if (json['production_id'] != null &&
        json['production_id'] is List &&
        json['production_id'].length > 1) {
      final val = json['production_id'][1];
      if (val is String) {
        moName = val;
      } else if (val is List && val.isNotEmpty) {
        moName = val[0].toString();
      }
    }

    String dateDone = '';
    if (json['date_done'] != null && json['date_done'] is String) {
      dateDone = json['date_done'];
    }

    // Helper to parse boolean from various formats
    bool parseBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      return false;
    }

    return ScrapItem(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      product: productName,
      location: locationName,
      scrapLocation: scrapLocationName,
      manufacturingOrder: moName,
      mo:
          (json['production_id'] != null &&
              json['production_id'] is List &&
              json['production_id'].length > 1)
          ? json['production_id'][1].toString()
          : '',
      company:
          (json['company_id'] != null &&
              json['company_id'] is List &&
              json['company_id'].length > 1)
          ? json['company_id'][1].toString()
          : '',
      origin: parseBool(json['origin']),
      date: dateDone,
      quantity: (json['scrap_qty'] ?? 0).toInt(),
      status: json['state'] ?? 'Unknown',
      replenish: parseBool(json['should_replenish']),
    );
  }
}
