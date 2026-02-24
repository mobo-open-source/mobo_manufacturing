import 'package:shared_preferences/shared_preferences.dart';

import '../../../../WorkOrders/model/work_order.dart';
import '../../../../core/company/session/company_session_manager.dart';
import '../../MoForm/models/bom.dart';
import '../../MoForm/models/product.dart';
import '../../MoForm/models/user_model.dart';
import '../model/bom_model.dart';

/// Service layer responsible for all Odoo RPC calls related to the MO (Manufacturing Order) list and creation screen.
///
/// Handles:
/// - Loading reference data (products, BOMs, users, activity types)
/// - Fetching BOM details, components, and related work orders
/// - Creating new manufacturing orders with moves and work orders
/// - Scheduling mail activities
class MoListService {
  int? userId;
  int? companyId;
  String url = '';

  /// Initializes the Odoo client/session using current company session.
  /// Throws exception if no active session exists.
  Future<void> initializeClient() async {
    final session = await CompanySessionManager.getCurrentSession();
    if (session == null) throw Exception("No active session");
  }

  /// Loads basic header info for a given BOM ID.
  /// Mainly retrieves the related product variant (variant_id and name).
  ///
  /// Returns null if BOM not found or product template has no variant.
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

  /// Loads work orders/operations defined in the BOM's routing.
  ///
  /// Returns list of WorkOrder objects with operation name, workcenter, expected duration, etc.
  /// Returns empty list if BOM has no operations or on error.
  Future<List<WorkOrder>> loadWorkOrdersByBom(int bomId) async {
    try {
      final bomResult = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.bom',
        'method': 'search_read',
        'args': [
          [
            ['id', '=', bomId],
          ],
        ],
        'kwargs': {
          'fields': ['operation_ids'],
        },
      });

      if (bomResult == null || bomResult.isEmpty) return [];

      final List operationIds = (bomResult[0]['operation_ids'] as List?) ?? [];

      if (operationIds.isEmpty) return [];

      final operations = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.routing.workcenter',
        'method': 'search_read',
        'args': [
          [
            ['id', 'in', operationIds],
          ],
        ],
        'kwargs': {
          'fields': ['id', 'name', 'workcenter_id', 'time_cycle_manual'],
        },
      });

      if (operations == null) return [];

      return (operations as List).map((op) {
        final wc = op['workcenter_id'] as List?;

        return WorkOrder(
          id: op['id'],
          operation: op['name'] ?? '',
          workCenter: wc != null ? wc[1] : '',
          workCenterId: wc != null ? wc[0] : 0,
          expectedDuration: (op['time_cycle_manual'] ?? 0).toDouble(),
          realDuration: 0.0,
          status: 'ready',
          product: '',
          quantity: 0,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Loads all component lines (mrp.bom.line) for a given BOM ID.
  ///
  /// Returns list of BomLineModel objects (product + quantity to consume).
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

  /// Loads all available products (product.product) from Odoo.
  ///
  /// Used to populate product selection dropdowns in MO creation.
  Future<List<Product>> loadProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final productItems =
          await CompanySessionManager.callKwWithCompany({
                'model': 'product.product',
                'method': 'search_read',
                'args': [[]],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (productItems != null) {
        return productItems.map((item) => Product.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Loads all Bills of Materials (mrp.bom) available in the system.
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

  /// Loads all Odoo users (res.users) — typically for responsible person selection.
  Future<List<UserModel>> loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;
      final userDetails =
          await CompanySessionManager.callKwWithCompany({
                'model': 'res.users',
                'method': 'search_read',
                'args': [[]],
                'kwargs': {},
              })
              as List<dynamic>?;

      if (userDetails != null) {
        return userDetails.map((item) => UserModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Creates a new Manufacturing Order (mrp.production) with raw moves and work orders.
  ///
  /// Expects moData map with:
  /// - 'moCreate': base fields for mrp.production
  /// - 'productData': list of raw material moves
  /// - 'workOrderData': list of work orders to create
  ///
  /// Returns true on success, false on any failure.
  Future<bool> createNewManufacturingOrder(moData) async {
    try {
      final moveRawIds = (moData['productData'] as List).map((prod) {
        return [
          0,
          0,
          {
            'product_id': prod['product_id'],
            'product_uom_qty': prod['product_uom_qty'],
          },
        ];
      }).toList();
      final workOrderIds = (moData['workOrderData'] as List).map((mo) {
        return [
          0,
          0,
          {
            'name': mo['name'],
            'workcenter_id': mo['workcenter_id'],
            'duration_expected': mo['duration_expected'],
            'product_uom_id': mo['product_uom_id'],
          },
        ];
      }).toList();
      final moCreateData = {
        ...moData['moCreate'],
        'move_raw_ids': moveRawIds,
        'workorder_ids': workOrderIds,
      };

      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.production',
        'method': 'create',
        'args': [moCreateData],
        'kwargs': {},
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Loads all activity types (mail.activity.type) for scheduling follow-ups.
  Future<List<dynamic>> loadActivityType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getInt('userId') ?? 0;

      final activityType = await CompanySessionManager.callKwWithCompany({
        'model': 'mail.activity.type',
        'method': 'search_read',
        'args': [[]],
        'kwargs': {},
      });

      if (activityType != null && activityType is List) {
        return activityType;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Schedules one or more mail activities using mail.activity.schedule wizard.
  ///
  /// Expects `details` map matching the wizard's create values.
  /// Calls both create + action_schedule_activities in sequence.
  Future<bool> schedule(details) async {
    try {
      final createResponse = await CompanySessionManager.callKwWithCompany({
        'model': 'mail.activity.schedule',
        'method': 'create',
        'args': [details],
        'kwargs': {},
      });

      if (createResponse != null) {
        final scheduleResponse = await CompanySessionManager.callKwWithCompany({
          'model': 'mail.activity.schedule',
          'method': 'action_schedule_activities',
          'args': [
            [createResponse],
          ],
          'kwargs': {},
        });

        return scheduleResponse != null;
      }

      return false;
    } catch (e) {
      return false;
    }
  }
}
