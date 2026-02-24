import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/company/session/company_session_manager.dart';
import '../../MoList/model/bom_model.dart';
import '../models/bom.dart';
import '../models/lost_reason.dart';
import '../models/mo_work_order.dart';
import '../models/product.dart';
import '../models/stock_move.dart';
import '../models/user_model.dart';
import '../models/work_center.dart';

/// Service layer responsible for all Odoo RPC calls related to Manufacturing Orders (MRP).
///
/// This class handles:
/// • Loading MO, work orders, components (stock moves), BOMs, products, users, work centers
/// • Creating/updating/deleting stock moves and work orders
/// • Starting/pausing/finishing work orders
/// • Confirming/cancelling/marking done/scrap/unbuild operations
/// • Blocking/unblocking work centers during production
///
/// All methods use `CompanySessionManager.callKwWithCompany` for authenticated Odoo RPC calls.
/// Most methods return empty lists or `false` on any exception (silent failure pattern).
class MoFormService {
  int? userId;
  int? companyId;
  String url = '';

  /// Initializes session context (currently just checks for active session).
  ///
  /// Throws exception if no session is active.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads all raw material stock moves (components) for a given manufacturing order.
  Future<List<StockMove>> loadProductMoves(int moId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final mrp = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', moId],
          ],
        ],
        'kwargs': {},
      });

      if (mrp != null && mrp is List && mrp.isNotEmpty) {
        final mrpRecord = mrp.first as Map<String, dynamic>;

        final moveItems =
            await CompanySessionManager.callKwWithCompany({
                  'model': 'stock.move',
                  'method': 'search_read',
                  'args': [
                    [
                      ['id', 'in', mrpRecord['move_raw_ids']],
                    ],
                  ],
                  'kwargs': {},
                })
                as List<dynamic>?;

        if (moveItems != null) {
          return moveItems.map((item) => StockMove.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads BOM lines (components) for a specific Bill of Materials.
  Future<List<StockMove>> loadBomLine(int bomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.bom.line',
        'method': 'search_read',
        'args': [
          [
            ['bom_id', '=', bomId],
          ],
        ],
        'kwargs': {
          'fields': ['product_id', 'product_qty'],
        },
      });

      if (result == null) return [];

      return (result as List).map((e) => StockMove.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Loads all work orders linked to a manufacturing order.
  Future<List<MoWorkOrder>> loadWorkOrders(int moId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final mrp = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', moId],
          ],
        ],
        'kwargs': {},
      });

      if (mrp != null && mrp is List && mrp.isNotEmpty) {
        final mrpRecord = mrp.first as Map<String, dynamic>;

        final moveItems =
            await CompanySessionManager.callKwWithCompany({
                  'model': 'mrp.workorder',
                  'method': 'search_read',
                  'args': [
                    [
                      ['id', 'in', mrpRecord['workorder_ids']],
                    ],
                  ],
                  'kwargs': {},
                })
                as List<dynamic>?;

        if (moveItems != null) {
          return moveItems.map((item) => MoWorkOrder.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads basic data of a single manufacturing order by ID.
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

  /// Loads detailed data of a single product by ID.
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

  /// Loads all available products (limited fields: id, name, list_price).
  Future<List<Product>> loadProducts() async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'product.product',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name', 'list_price'],
        },
      });

      if (result is List) {
        return result.map((item) => Product.fromJson(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Loads all Bills of Materials (no domain filter — full list).
  Future<List<Bom>> loadBom() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final bomDetails =
          await CompanySessionManager.callKwWithCompany({
                'model': 'mrp.bom',
                'method': 'search_read',
                'args': [[]],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (bomDetails != null) {
        return bomDetails.map((item) => Bom.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Gets the product template ID from a product variant ID.
  Future<int?> loadProductTemplateId(int productId) async {
    try {
      final result =
          await CompanySessionManager.callKwWithCompany({
                'model': 'product.product',
                'method': 'search_read',
                'args': [
                  [
                    ['id', '=', productId],
                  ],
                ],
                'kwargs': {
                  'fields': ['product_tmpl_id'],
                },
              })
              as List<dynamic>?;

      if (result != null && result.isNotEmpty) {
        final tmpl = result[0]['product_tmpl_id'];
        if (tmpl is List && tmpl.isNotEmpty) {
          return tmpl[0] as int;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Loads all BOMs for a given product template ID.
  Future<List<Bom>> loadBomId(id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final bomDetails =
          await CompanySessionManager.callKwWithCompany({
                'model': 'mrp.bom',
                'method': 'search_read',
                'args': [
                  [
                    ['product_tmpl_id', '=', id],
                  ],
                ],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (bomDetails != null) {
        return bomDetails.map((item) => Bom.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads all users (limited fields: id, name, login, email).
  Future<List<UserModel>> loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      final userDetails = await CompanySessionManager.callKwWithCompany({
        'model': 'res.users',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {
          'fields': ['id', 'name', 'login', 'email'],
        },
      });

      if (userDetails is List) {
        return userDetails.map((item) => UserModel.fromJson(item)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Loads all work centers.
  Future<List<WorkCenter>> loadWorkCenters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final workCenterDetails =
          await CompanySessionManager.callKwWithCompany({
                'model': 'mrp.workcenter',
                'method': 'search_read',
                'args': [[]],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (workCenterDetails != null) {
        return workCenterDetails
            .map((item) => WorkCenter.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads products that can be scrapped for this MO.
  ///
  /// Logic differs:
  /// - If MO is 'done' → only the produced product
  /// - Otherwise → all raw materials from stock moves
  Future<List<Product>> loadProductScrap(
    moItem,
    List<StockMove> moveProducts,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      List<dynamic> productItems;
      List<dynamic> productIds = [];

      if (moItem[0]['state'] == 'done') {
        productItems =
            await CompanySessionManager.callKwWithCompany({
                  'model': 'product.product',
                  'method': 'search_read',
                  'args': [
                    [
                      ['id', '=', moItem[0]['product_id'][0]],
                    ],
                  ],
                  'kwargs': {},
                })
                as List<dynamic>? ??
            [];
      } else {
        for (var stockMove in moveProducts) {
          if (stockMove.productId != null && stockMove.productId!.isNotEmpty) {
            productIds.add(stockMove.productId![0]);
          }
        }

        productItems =
            await CompanySessionManager.callKwWithCompany({
                  'model': 'product.product',
                  'method': 'search_read',
                  'args': [
                    [
                      ['id', 'in', productIds],
                    ],
                  ],
                  'kwargs': {},
                })
                as List<dynamic>? ??
            [];
      }

      return productItems.map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Loads stock move lines for a specific stock move (detailed consumption tracking).
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

  /// Loads all scrap records linked to this manufacturing order.
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

  /// Loads all unbuild records linked to this manufacturing order.
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

  /// Loads all available work center productivity loss reasons (used for blocking).
  Future<List<LostReason>> loadLostReason() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final lostReasonItems =
          await CompanySessionManager.callKwWithCompany({
                'model': 'mrp.workcenter.productivity.loss',
                'method': 'search_read',
                'args': [[]],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (lostReasonItems != null) {
        return lostReasonItems
            .map((item) => LostReason.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// **Deprecated / unsafe** — attempts to add a new component line by writing to `move_raw_ids`.
  ///
  /// Note: This method is likely incorrect — writing command [0,0,{...}] should usually be done via
  /// `create` on `stock.move` or proper onchange/compute logic on mrp.production.
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

  /// Updates fields on an existing stock move (product, name, quantity, to-consume qty).
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

  /// Updates the `picked` flag on a stock move (used during manual consumption).
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

  /// Deletes a stock move (component line) from the manufacturing order.
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

  /// Starts a work order (calls `button_start` on `mrp.workorder`).
  Future<dynamic> startWorkOrder(int moId, int workOrderId) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_start',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Finishes / marks a work order as done (`button_finish`).
  Future<dynamic> stopWorkOrder(int moId, int workOrderId) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_finish',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Sets a work order to pending / paused state (`button_pending`).
  Future<dynamic> pauseWorkOrder(int moId, int workOrderId) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_pending',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Blocks production at a work center (creates productivity loss record + calls `button_block`).
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

  /// Unblocks a work order (`button_unblock` on `mrp.workorder`).
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

  /// Loads header information from a BOM (currently variant/product info).
  Future<Map<String, dynamic>?> loadBomHeader(int bomId) async {
    try {
      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.bom',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', bomId],
          ],
        ],
        'kwargs': {
          'fields': ['product_tmpl_id'],
        },
      });

      if (result != null && result is List && result.isNotEmpty) {
        final productTmpl = result[0]['product_tmpl_id'] as List?;
        if (productTmpl == null || productTmpl.isEmpty) return null;

        final tmplId = productTmpl[0];

        final product = await CompanySessionManager.callKwWithCompany({
          'model': 'product.template',
          'method': 'search_read',
          'args': [
            [
              ['id', '=', tmplId],
            ],
          ],
          'kwargs': {
            'fields': ['product_variant_id'],
          },
        });

        if (product != null && product is List && product.isNotEmpty) {
          final variant = product[0]['product_variant_id'] as List?;
          return {
            'variant_id': variant != null ? variant[0] : 0,
            'variant_name': variant != null ? variant[1] : '',
          };
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Loads detailed component lines of a BOM (uses `BomLineModel`).
  Future<List<BomLineModel>> loadBomComponents(int bomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      final result = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.bom.line',
        'method': 'search_read',
        'args': [
          [
            ['bom_id', '=', bomId],
          ],
        ],
        'kwargs': {
          'fields': ['product_id', 'product_qty'],
        },
      });

      if (result == null) return [];

      return (result as List)
          .map((line) => BomLineModel.fromJson(line))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Marks the entire MO as done (`button_mark_done`).
  Future<dynamic> produceAll(int moId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'button_mark_done',
        'args': [
          [moId],
        ],
        'kwargs': {},
      });
      return response != null;
    } catch (e) {
      try {
        final errorString = e.toString();
        final regex = RegExp(r'\{.*\}');
        final match = regex.firstMatch(errorString);
        if (match != null) {
          final errorJson = match.group(0);
          final Map<String, dynamic> errorData = jsonDecode(errorJson!);
        }
      } catch (_) {}

      return false;
    }
  }

  /// Cancels the manufacturing order (`action_cancel`).
  Future<dynamic> cancelMo(int moId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'action_cancel',
        'args': [
          [moId],
        ],
        'kwargs': {},
      });

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Confirms the manufacturing order (`action_confirm` — usually generates work orders).
  Future<dynamic> confirmMo(int moId) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'action_confirm',
        'args': [
          [moId],
        ],
        'kwargs': {},
      });

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Updates header fields of the manufacturing order.
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

  /// Creates a new work order (used when adding manual operations).
  Future<dynamic> updateWorkOrderDetails(
    Map<String, dynamic> updatedDetails,
  ) async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'create',
        'args': [updatedDetails],
        'kwargs': {},
      });

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Performs an unbuild operation (create + validate `mrp.unbuild` record).
  Future<dynamic> unbuildMo(dynamic moId) async {
    try {
      final create = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.unbuild',
        'method': 'create',
        'args': [
          {
            'mo_id': moId[0]['id'],
            'product_id': (moId[0]['product_id'] is List)
                ? moId[0]['product_id'][0]
                : null,
            'product_qty': moId[0]['product_qty'],
            'lot_id': (moId[0]['lot_producing_id'] is List)
                ? moId[0]['lot_producing_id'][0]
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

  /// Creates and validates a scrap record (`stock.scrap`).
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
