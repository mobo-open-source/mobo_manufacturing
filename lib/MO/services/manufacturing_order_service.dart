import 'package:shared_preferences/shared_preferences.dart';

import '../../core/company/session/company_session_manager.dart';

/// Core service for all Odoo RPC operations related to Manufacturing Orders (mrp.production).
///
/// Handles:
/// - Counting and fetching paginated/filtered MO lists
/// - Loading single MO details and related records (moves, scraps, unbuilds)
/// - CRUD operations on MO lines (add/update/delete raw material moves)
/// - Work order control (start, pause, stop)
/// - MO updates, unbuild, and scrap actions
class ManufacturingOrderService {
  int? userId;
  int? companyId;
  String url = '';

  /// Initializes Odoo session using current company context.
  /// Throws exception if no active session is found.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Returns total count of Manufacturing Orders matching current search & filters.
  ///
  /// Used for pagination UI (total pages calculation).
  /// Supports search across name/state/product/BOM and various status filters.
  Future<int> fetchManufacturingOrdersCount(
    int page,
    int itemsPerPage, {
    String searchTerm = '',
    String selectedView = "list",
    List<String> selectedFilters = const [],
  }) async {
    try {
      final offset = page * itemsPerPage;
      List<dynamic> domain = [];

      // Search domain (case-insensitive partial match)
      if (searchTerm.isNotEmpty) {
        domain = [
          '|',
          '|',
          '|',
          ['name', 'ilike', searchTerm],
          ['state', 'ilike', searchTerm],
          ['product_id', 'ilike', searchTerm],
          ['bom_id', 'ilike', searchTerm],
        ];
      }

      // Build complex status filter domain
      if (selectedFilters.isNotEmpty) {
        List<dynamic> statusDomain = [];
        for (var filter in selectedFilters) {
          switch (filter) {
            case "to_do":
              statusDomain.add([
                'state',
                'in',
                ['draft', 'confirmed', 'progress', 'to_close'],
              ]);
              break;
            case "done":
              statusDomain.add(['state', '=', 'done']);
              break;
            case "cancel":
              statusDomain.add(['state', '=', 'cancel']);
              break;
            case "draft":
              statusDomain.add(['state', '=', 'draft']);
              break;
            case "confirm":
              statusDomain.add(['state', '=', 'confirmed']);
              break;
            case "planned":
              statusDomain.add(['is_planned', '=', true]);
              break;
            case "progress":
              statusDomain.add(['state', '=', 'progress']);
              break;
            case "close":
              statusDomain.add(['state', '=', 'to_close']);
              break;
            case "waiting_components":
              statusDomain.add([
                'reservation_state',
                'in',
                ['waiting', 'confirmed'],
              ]);
              break;
            case "mo_ready":
              statusDomain.add(['reservation_state', '=', 'assigned']);
              break;
            case "delays":
              statusDomain.add('|');
              statusDomain.add(['delay_alert_date', '!=', false]);
              statusDomain.add('&');
              statusDomain.add([
                'date_deadline',
                '<',
                DateTime.now().toIso8601String(),
              ]);
              statusDomain.add(['state', '=', 'confirmed']);
              break;
            case "late_components":
              statusDomain.add(['components_availability_state', '=', 'late']);
              break;
          }
        }

        if (statusDomain.isNotEmpty) {
          if (statusDomain.length > 1) {
            domain.add('|');
          }
          domain.addAll(statusDomain);
        }
      }

      final kwargs = <String, dynamic>{};

      if (selectedView != "calendar") {
        kwargs['limit'] = itemsPerPage;
        kwargs['offset'] = offset;
      } else {}
      final count = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'search_count',
        'args': [domain],
        'kwargs': {},
      });
      return count as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Fetches paginated list of Manufacturing Orders with applied search & filters.
  ///
  /// Returns list of MO records as maps (full fields unless limited).
  /// Throws exception on failure (unlike count method).
  Future<List<Map<String, dynamic>>> fetchManufacturingOrders(
    int page,
    int itemsPerPage, {
    String searchTerm = '',
    String selectedView = "list",
    List<String> selectedFilters = const [],
  }) async {
    try {
      final offset = page * itemsPerPage;
      List<dynamic> domain = [];

      // Same search & filter domain logic as count method
      if (searchTerm.isNotEmpty) {
        domain = [
          '|',
          '|',
          '|',
          ['name', 'ilike', searchTerm],
          ['state', 'ilike', searchTerm],
          ['product_id', 'ilike', searchTerm],
          ['bom_id', 'ilike', searchTerm],
        ];
      }

      if (selectedFilters.isNotEmpty) {
        List<dynamic> statusDomain = [];
        for (var filter in selectedFilters) {
          switch (filter) {
            case "to_do":
              statusDomain.add([
                'state',
                'in',
                ['draft', 'confirmed', 'progress', 'to_close'],
              ]);
              break;
            case "done":
              statusDomain.add(['state', '=', 'done']);
              break;
            case "cancel":
              statusDomain.add(['state', '=', 'cancel']);
              break;
            case "draft":
              statusDomain.add(['state', '=', 'draft']);
              break;
            case "confirm":
              statusDomain.add(['state', '=', 'confirmed']);
              break;
            case "planned":
              statusDomain.add(['is_planned', '=', true]);
              break;
            case "progress":
              statusDomain.add(['state', '=', 'progress']);
              break;
            case "close":
              statusDomain.add(['state', '=', 'to_close']);
              break;
            case "waiting_components":
              statusDomain.add([
                'reservation_state',
                'in',
                ['waiting', 'confirmed'],
              ]);
              break;
            case "mo_ready":
              statusDomain.add(['reservation_state', '=', 'assigned']);
              break;
            case "delays":
              statusDomain.add('|');
              statusDomain.add(['delay_alert_date', '!=', false]);
              statusDomain.add('&');
              statusDomain.add([
                'date_deadline',
                '<',
                DateTime.now().toIso8601String(),
              ]);
              statusDomain.add(['state', '=', 'confirmed']);
              break;
            case "late_components":
              statusDomain.add(['components_availability_state', '=', 'late']);
              break;
          }
        }

        if (statusDomain.isNotEmpty) {
          if (statusDomain.length > 1) {
            domain.add('|');
          }
          domain.addAll(statusDomain);
        }
      }
      final kwargs = <String, dynamic>{};

      if (selectedView != "calendar") {
        kwargs['limit'] = itemsPerPage;
        kwargs['offset'] = offset;
      } else {}

      final moItems = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'search_read',
        'args': [domain],
        'kwargs': kwargs,
      });

      return List<Map<String, dynamic>>.from(moItems ?? []);
    } catch (e) {
      throw Exception("Failed to fetch Manufacturing Orders: $e");
    }
  }

  /// Loads full details of a single Manufacturing Order by ID.
  Future<List<dynamic>> loadMo(int moId) async {
    try {
      final moItems =
          await CompanySessionManager.callKwWithCompany({
                'model': 'mrp.production',
                'method': 'search_read',
                'args': [
                  [
                    ['id', '=', moId],
                  ],
                ],
                'kwargs': {'fields': []},
              })
              as List<dynamic>?;

      return moItems ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Fetches detailed info for a single product (product.product).
  Future<List<dynamic>> loadProductDetails(int id) async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('userId') ?? 0;

    final productItems = await CompanySessionManager.callKwWithCompany({
      'model': 'product.product',
      'method': 'search_read',
      'args': [
        [
          ['id', '=', id],
        ],
      ],
      'kwargs': {},
    });

    return productItems ?? [];
  }

  /// Loads stock move lines related to a specific move (stock.move.line).
  Future<List<dynamic>> loadProductsMoveLine(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      final productItems =
          await CompanySessionManager.callKwWithCompany({
                'model': 'stock.move.line',
                'method': 'search_read',
                'args': [
                  [
                    ['move_id', '=', id],
                  ],
                ],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (productItems != null) {
        return productItems;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads scrap records linked to a Manufacturing Order.
  Future<List<dynamic>> loadStockScrap(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      final scrapItems =
          await CompanySessionManager.callKwWithCompany({
                'model': 'stock.scrap',
                'method': 'search_read',
                'args': [
                  [
                    ['production_id', '=', id],
                  ],
                ],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (scrapItems != null) {
        return scrapItems;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads unbuild orders (mrp.unbuild) related to a Manufacturing Order.
  Future<List<dynamic>> loadUnbuildOrders(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      final unbuildItems =
          await CompanySessionManager.callKwWithCompany({
                'model': 'mrp.unbuild',
                'method': 'search_read',
                'args': [
                  [
                    ['mo_id', '=', id],
                  ],
                ],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (unbuildItems != null) {
        return unbuildItems;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Adds a new raw material line (move_raw_ids) to an existing MO.
  Future<int?> addProductToLine(
    int moId,
    int productId,
    String productName,
    double toConsume,
    double quantity,
    int product_id,
  ) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'write',
        'args': [
          moId,
          {
            'product_id': product_id,
            'move_raw_ids': [
              [
                0,
                0,
                {
                  'product_id': productId,
                  'product_uom_qty': toConsume,
                  'quantity': quantity,
                },
              ],
            ],
          },
        ],
        'kwargs': {},
      });

      return result;
    } catch (e) {
      return null;
    }
  }

  /// Updates an existing stock move (raw material line).
  Future<bool> updateProductMove(
    int moveId,
    int productId,
    String productName,
    double quantity,
    double toConsume,
  ) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'stock.move',
        'method': 'write',
        'args': [
          [moveId],
          {
            'product_id': productId,
            'name': productName,
            'quantity': quantity,
            'product_uom_qty': toConsume,
          },
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Marks a stock move as picked/consumed or un-picked.
  Future<bool> updateConsume(int moveId, bool consume) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'stock.move',
        'method': 'write',
        'args': [
          [moveId],
          {'picked': consume},
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Deletes a stock move (raw material line) from MO.
  Future<bool> deleteProductMove(int moveId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'stock.move',
        'method': 'unlink',
        'args': [
          [moveId],
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Starts a work order (sets to in-progress).
  Future<dynamic> startWorkOrder(int moId, int workOrderId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_start',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Finishes/completes a work order.
  Future<dynamic> stopWorkOrder(int moId, int workOrderId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_finish',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Pauses a work order (sets to pending).
  Future<dynamic> pauseWorkOrder(int moId, int workOrderId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_pending',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Blocks a work order with a loss reason (productivity loss entry).
  Future<bool> blockWorkOrder(
    int moId,
    int workOrderId,
    int workCenterId,
    selectedReason,
    String description,
  ) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workcenter.productivity',
        'method': 'create',
        'args': [
          {
            'loss_id': selectedReason,
            'description': description,
            'workorder_id': workOrderId,
            'workcenter_id': workCenterId,
            'production_id': moId,
          },
        ],
        'kwargs': {},
      });

      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workcenter.productivity',
        'method': 'button_block',
        'args': [
          [response],
        ],
        'kwargs': {},
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Unblocks a previously blocked work order.
  Future<dynamic> unblockWorkOrder(
    int moId,
    int workOrderId,
    int workCenterId,
  ) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_unblock',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Updates main fields of a Manufacturing Order.
  Future<dynamic> updateManufacturingDetails(
    Map<String, dynamic> updatedDetails,
    int id,
  ) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'write',
        'args': [
          [id],
          updatedDetails,
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Creates and validates an unbuild order (mrp.unbuild) for the given MO.
  Future<dynamic> unbuildMo(dynamic moId) async {
    try {
      final create = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.unbuild',
        'method': 'create',
        'args': [
          {
            'mo_id': moId['id'],
            'product_id': (moId['product_id'] is List)
                ? moId['product_id'][0]
                : null,
            'product_qty': moId['product_qty'],
            'lot_id': (moId['lot_producing_id'] is List)
                ? moId['lot_producing_id'][0]
                : null,
          },
        ],
        'kwargs': {},
      });

      if (create != null) {
        final response = await CompanySessionManager.callKwWithCompany({
          'model': 'mrp.unbuild',
          'method': 'action_validate',
          'args': [
            [create],
          ],
          'kwargs': {},
        });

        return response != null;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Creates and validates a scrap record (stock.scrap) linked to the MO.
  Future<dynamic> scrapMo(moDetails) async {
    try {
      final create = await CompanySessionManager.callKwWithCompany({
        'model': 'stock.scrap',
        'method': 'create',
        'args': [moDetails],
        'kwargs': {},
      });

      if (create != null) {
        final response = await CompanySessionManager.callKwWithCompany({
          'model': 'stock.scrap',
          'method': 'action_validate',
          'args': [
            [create],
          ],
          'kwargs': {},
        });

        return response != null;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
