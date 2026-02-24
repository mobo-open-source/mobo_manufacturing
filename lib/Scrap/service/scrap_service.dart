import 'package:intl/intl.dart';

import '../../core/company/session/company_session_manager.dart';
import '../model/scrap.dart';

/// Service layer for all Odoo RPC operations related to Scrap records (stock.scrap).
///
/// Handles:
/// - Loading reference data (products, manufacturing orders, companies)
/// - Paginated fetching of scrap items with search/filter support
/// - Loading single scrap form/details
/// - Validating, confirming (with insufficient qty warning), updating scrap records
class ScrapService {
  int? userId;
  int? companyId;
  String url = '';

  /// Fixed page size used for pagination across the app
  static const int itemsPerPage = 40;

  /// Initializes the Odoo client/session using current company context.
  /// Throws exception if no active session exists.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads minimal product data (id + name) for dropdowns/filters.
  ///
  /// Returns list of maps or null on failure/error.
  Future<List<Map<String, dynamic>>?> loadProduct() async {
    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'product.product',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name'],
      },
    });
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      return null;
    }
  }

  /// Loads minimal MO data (id + name) for reference/filtering.
  ///
  /// Returns list of maps or null on failure.
  Future<List<Map<String, dynamic>>?> loadMo() async {
    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'mrp.production',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name'],
      },
    });
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      return null;
    }
  }

  /// Loads minimal company data (id + name) — usually for context/display.
  ///
  /// Returns list of maps or null on failure.
  Future<List<Map<String, dynamic>>?> loadCompany() async {
    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'res.company',
      'method': 'search_read',
      'args': [],
      'kwargs': {
        'fields': ['id', 'name'],
      },
    });
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      return null;
    }
  }

  /// Main method to fetch paginated scrap items with optional filters.
  ///
  /// Returns tuple: (list of ScrapItem, total count)
  /// - Supports search, product filter, single date filter, status filters
  /// - Client-side grouping is not applied here (handled in BLoC)
  Future<(List<ScrapItem>, int)> loadScrap({
    required int page,
    String? search,
    int? productId,
    DateTime? date,
    List<String>? filter = const [],
    String? group,
  }) async {
    final offset = page * itemsPerPage;

    List<dynamic> domain = [];

    // Search domain
    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim();
      domain = [
        ['name', 'ilike', term],
      ];
    }

    // Status filters (draft/done)
    if (filter != null && filter.isNotEmpty) {
      if (filter.contains('done')) {
        domain.add(['state', '=', 'done']);
      }

      if (filter.contains('draft')) {
        domain.add(['state', '=', 'draft']);
      }
    }

    // Product filter
    if (productId != null) {
      domain.add(['product_id', '=', productId]);
    }

    // Single date filter (date_done within the day)
    if (date != null) {
      final from = DateFormat('yyyy-MM-dd 00:00:00').format(date);
      final to = DateFormat('yyyy-MM-dd 23:59:59').format(date);
      domain.add(['date_done', '>=', from]);
      domain.add(['date_done', '<=', to]);
    }

    // Fetch paginated records
    final records = await CompanySessionManager.callKwWithCompany({
      'model': 'stock.scrap',
      'method': 'search_read',
      'args': [domain],
      'kwargs': {
        'fields': [
          'id',
          'name',
          'scrap_qty',
          'state',
          'product_id',
          'date_done',
          'production_id',
          'origin',
          'company_id',
          'should_replenish',
        ],
        'limit': itemsPerPage,
        'offset': offset,
      },
    });

    // Get total count for pagination
    final total =
        await CompanySessionManager.callKwWithCompany({
              'model': 'stock.scrap',
              'method': 'search_count',
              'args': [domain],
              'kwargs': {},
            })
            as int? ??
        0;

    final List<ScrapItem> items = (records ?? [])
        .map<ScrapItem>((json) => ScrapItem.fromJson(json))
        .toList();

    return (items, total);
  }

  /// Loads full details of a single scrap record for form/display.
  ///
  /// Returns list of maps (usually one item) or null on failure.
  Future<List<Map<String, dynamic>>?> loadScrapForm(int scrapId) async {
    final response = await CompanySessionManager.callKwWithCompany({
      'model': 'stock.scrap',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', scrapId],
        ],
      ],
      'kwargs': {
        'fields': [
          'id',
          'name',
          'scrap_qty',
          'state',
          'product_id',
          'date_done',
          'production_id',
          'origin',
          'company_id',
          'should_replenish',
        ],
      },
    });

    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    } else {
      return null;
    }
  }

  /// Validates a scrap record (marks as done / processes stock move).
  ///
  /// Returns response from Odoo or null on error.
  Future<dynamic> validateScrap(int scrapId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'stock.scrap',
        'method': 'action_validate',
        'args': [
          [scrapId],
        ],
        'kwargs': {},
      });

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Confirms a scrap operation — handles insufficient qty warning wizard.
  ///
  /// Creates and validates the warning wizard if needed.
  /// Returns true on success, false on failure/error.
  Future<bool> confirmScrap({
    required int scrapId,
    required int productId,
    required int locationId,
    required String uom,
    required double qty,
  }) async {
    try {
      final createResponse = await CompanySessionManager.callKwWithCompany({
        'model': 'stock.warn.insufficient.qty.scrap',
        'method': 'create',
        'args': [
          {
            'scrap_id': scrapId,
            'product_id': productId,
            'location_id': locationId,
            'product_uom_name': uom,
            'quantity': qty,
          },
        ],
        'kwargs': {},
      });

      if (createResponse != null) {
        final doneResponse = await CompanySessionManager.callKwWithCompany({
          'model': 'stock.warn.insufficient.qty.scrap',
          'method': 'action_done',
          'args': [
            [createResponse],
          ],
          'kwargs': {},
        });

        return doneResponse != null;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Updates fields of an existing scrap record.
  ///
  /// Returns true on success, false on any failure.
  Future<bool> updateScrap(int scrapId, details) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'stock.scrap',
        'method': 'write',
        'args': [
          [scrapId],
          details,
        ],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}
