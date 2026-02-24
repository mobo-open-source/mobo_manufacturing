import 'package:odoo_rpc/odoo_rpc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../MO/pages/MoForm/models/work_center.dart';
import '../../core/company/session/company_session_manager.dart';
import '../model/lost_wo_reason.dart';
import '../model/work_order.dart';

/// Service layer for all Odoo RPC operations related to Work Orders (mrp.workorder).
///
/// Responsibilities:
/// - Fetching work orders (full list or paginated with search/filter support)
/// - Loading reference data (work centers, lost time reasons)
/// - Controlling work order lifecycle: start, pause, finish
/// - Extracting user-friendly error messages from Odoo exceptions
class WorkOrderService {
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

  /// Fetches all work orders (unpaginated) — use with caution for large datasets.
  ///
  /// Returns list of WorkOrder objects or throws on error.
  Future<List<WorkOrder>> fetchWorkOrders() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'state',
            'production_id',
            'workcenter_id',
            'product_id',
            'qty_remaining',
            'duration_expected',
            'duration',
          ],
        },
      });

      return (response ?? [])
          .map<WorkOrder>((json) => WorkOrder.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception("Failed to fetch Manufacturing Orders: $e");
    }
  }

  /// Loads all available work centers (mrp.workcenter) for dropdowns/filters.
  ///
  /// Returns list of WorkCenter objects or throws on error.
  Future<List<WorkCenter>> fetchWorkCenter() async {
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workcenter',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'fields': ['id', 'name'],
        },
      });

      final List<WorkCenter> workCenters = response
          .cast<Map<String, dynamic>>()
          .map<WorkCenter>(WorkCenter.fromJson)
          .toList();

      return workCenters;
    } catch (e) {
      throw Exception("Failed to fetch Manufacturing Orders: $e");
    }
  }

  /// Loads paginated work orders with optional search and custom domain filters.
  ///
  /// Returns PaginatedWorkOrders object containing items and total count.
  /// Throws exception on failure.
  Future<PaginatedWorkOrders> fetchWorkOrdersPaginated({
    required int page,
    String search = '',
    List<dynamic> domain = const [],
  }) async {
    final int offset = page * itemsPerPage;
    List<dynamic> finalDomain = List.from(domain);

    // Add search to domain (OR with existing filters if any)
    if (search.isNotEmpty) {
      if (finalDomain.isEmpty) {
        finalDomain = [
          ['name', 'ilike', search],
        ];
      } else {
        finalDomain = [
          '|',
          ['name', 'ilike', search],
          ...finalDomain,
        ];
      }
    }
    try {
      final response = await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'search_read',
        'args': [finalDomain],
        'kwargs': {
          'fields': [
            'id',
            'name',
            'state',
            'production_id',
            'workcenter_id',
            'product_id',
            'qty_remaining',
            'duration_expected',
            'duration',
          ],
          'limit': itemsPerPage,
          'offset': offset,
        },
      });

      final total =
          await CompanySessionManager.callKwWithCompany({
                'model': 'mrp.workorder',
                'method': 'search_count',
                'args': [finalDomain],
                'kwargs': {},
              })
              as int? ??
          0;

      final List<WorkOrder> items = (response ?? [])
          .map<WorkOrder>((json) => WorkOrder.fromJson(json))
          .toList();

      return PaginatedWorkOrders(
        items: items,
        totalCount: total,
        page: page,
        itemsPerPage: itemsPerPage,
      );
    } catch (e) {
      throw Exception("Failed to fetch Manufacturing Orders: $e");
    }
  }

  /// Loads all lost time/block reasons (mrp.workcenter.productivity.loss).
  ///
  /// Returns list of LostWoReason objects or empty list on failure.
  Future<List<LostWoReason>> loadLostReason() async {
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
            .map((item) => LostWoReason.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception("Failed to fetch Manufacturing Orders: $e");
    }
  }

  /// Extracts user-friendly error message from OdooException.
  ///
  /// Tries to parse common Odoo error types:
  /// - ValidationError
  /// - AccessError
  /// - UserError
  /// Falls back to last meaningful line or full string.
  String? extractOdooError(OdooException e) {
    final text = e.toString();

    // ValidationError
    final validationMatch = RegExp(
      r'ValidationError[:\s]*([\s\S]*?)(?=, message:|, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (validationMatch != null) {
      return validationMatch.group(1)!.trim();
    }

    // AccessError
    final accessMatch = RegExp(
      r'name[:\s]*odoo\.exceptions\.AccessError[,:\s]*message[:\s]*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (accessMatch != null) {
      return accessMatch.group(1)!.trim();
    }

    // UserError
    final userMatch = RegExp(
      r'name[:\s]*odoo\.exceptions\.UserError[,:\s]*message[:\s]*([\s\S]*?)(?=, arguments:|, context:|\}$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (userMatch != null) {
      return userMatch.group(1)!.trim();
    }
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      return lines.last;
    }
    return text;
  }

  /// Starts a work order (sets state to 'progress').
  ///
  /// Returns map with 'success' flag and optional 'error' message.
  Future<Map<String, dynamic>> startWorkOrder(int workOrderId) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_start',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return {"success": true};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "error":
            errorMsg ?? "Failed to start work order, Please try again later",
      };
    } catch (e) {
      return {
        "success": false,
        "error": "Something went wrong. Please try again.",
      };
    }
  }

  /// Finishes/completes a work order (sets state to 'done').
  ///
  /// Returns map with 'success' flag and optional 'error' message.
  Future<Map<String, dynamic>> stopWorkOrder(int workOrderId) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_finish',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return {"success": true};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "error":
        errorMsg ?? "Failed to stop work order, Please try again later",
      };
    }  catch (e) {
      return {
        "success": false,
        "error": "Something went wrong. Please try again.",
      };
    }
  }

  /// Pauses a work order (sets state to 'pending').
  ///
  /// Returns map with 'success' flag and optional 'error' message.
  Future<Map<String, dynamic>> pauseWorkOrder(int workOrderId) async {
    try {
      await CompanySessionManager.callKwWithCompany({
        'model': 'mrp.workorder',
        'method': 'button_pending',
        'args': [
          [workOrderId],
        ],
        'kwargs': {},
      });
      return {"success": true};
    } on OdooException catch (e) {
      final errorMsg = extractOdooError(e);
      return {
        "success": false,
        "error":
        errorMsg ?? "Failed to pause work order, Please try again later",
      };
    } catch (e) {
      return {
        "success": false,
        "error": "Something went wrong. Please try again.",
      };
    }
  }
}

/// Paginated result wrapper for work orders
class PaginatedWorkOrders {
  final List<WorkOrder> items;
  final int totalCount;
  final int page;
  final int itemsPerPage;

  PaginatedWorkOrders({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.itemsPerPage,
  });

  /// Human-readable current page range (e.g. "1-40")
  String get pageRange {
    final start = page * itemsPerPage + 1;
    final end = (start + items.length - 1).clamp(0, totalCount);
    return '$start-$end';
  }

  /// Whether there is a next page available
  bool get hasNext => (page + 1) * itemsPerPage < totalCount;

  /// Whether there is a previous page
  bool get hasPrev => page > 0;
}
