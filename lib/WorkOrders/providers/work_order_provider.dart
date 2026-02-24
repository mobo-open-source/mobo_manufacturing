import 'package:flutter/material.dart';
import '../../MO/pages/MoForm/models/work_center.dart';
import '../data/work_order_timer_manager.dart';
import '../model/work_order.dart';
import '../model/lost_wo_reason.dart';
import '../service/work_order_service.dart';

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

/// Provider (ChangeNotifier) that manages the state and business logic for the Work Order list screen.
///
/// Responsibilities:
/// - Fetching and paginating work orders from the service
/// - Managing search text, status filters, work center filter, and grouping
/// - Controlling real-time timers for running work orders
/// - Handling start/pause/finish actions with loading states
/// - Notifying UI of loading, error, and data changes
class WorkOrderProvider extends ChangeNotifier {
  final WorkOrderTimerManager _timerManager = WorkOrderTimerManager();
  final WorkOrderService _service;

  WorkOrderProvider(this._service);

  // Core data
  List<WorkOrder> _workOrders = [];

  List<WorkOrder> get workOrders => _workOrders;

  List<LostWoReason> _lostReasons = [];

  List<LostWoReason> get lostReasons => _lostReasons;

  List<WorkCenter> _workCenters = [];

  List<WorkCenter> get workCenters => _workCenters;

  // Loading & error states
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  bool _isPaginationLoading = false;

  bool get isPaginationLoading => _isPaginationLoading;

  String? _errorMessage;
  String? _alertMessage;

  String? get errorMessage => _errorMessage;

  String? get alertMessage => _alertMessage;

  // Pagination
  int _currentPage = 0;

  int get currentPage => _currentPage;

  int _totalCount = 0;

  int get totalCount => _totalCount;

  String? _groupBy;

  String? get groupBy => _groupBy;

  // Group expand/collapse state
  Map<String, bool> groupExpanded = {};

  bool get hasError => _errorMessage != null && _errorMessage!.isNotEmpty;

  /// Toggles expand/collapse state of a group in grouped view
  void toggleGroup(String groupName) {
    groupExpanded[groupName] = !(groupExpanded[groupName] ?? true);
    notifyListeners();
  }

  /// Sets grouping criteria and resets pagination
  void setGroupBy(String? value) {
    _groupBy = value;
    _currentPage = 0;
    notifyListeners();
    loadWorkOrders(reset: true);
  }

  String get pageRange => PaginatedWorkOrders(
    items: _workOrders,
    totalCount: _totalCount,
    page: _currentPage,
    itemsPerPage: WorkOrderService.itemsPerPage,
  ).pageRange;

  String _searchText = '';

  String get searchText => _searchText;

  List<String> _selectedStatuses = [];

  List<String> get selectedStatuses => _selectedStatuses;

  int? _selectedWorkCenterId;

  int? get selectedWorkCenterId => _selectedWorkCenterId;

  bool get hasFiltersApplied =>
      _selectedStatuses != null || _selectedWorkCenterId != null;

  bool _isSearching = false;

  bool get isSearching => _isSearching;

  // Timer helpers
  bool isTimerRunning(int id) => _timerManager.isRunning(id);

  Duration getElapsedTime(int id) => _timerManager.getElapsed(id);

  WorkOrderTimerManager get timerManager => _timerManager;

  /// Clears all active filters and resets pagination
  void clearFilters() {
    _selectedStatuses.clear();
    _selectedWorkCenterId = null;
    _currentPage = 0;
    notifyListeners();
  }

  /// Parses a formatted duration string (HH:mm:ss or mm:ss) into Duration
  Duration parseFormattedDuration(String? formatted) {
    if (formatted == null || formatted.isEmpty) return Duration.zero;

    final parts = formatted.trim().split(':').map(int.tryParse).toList();

    if (parts.any((e) => e == null)) return Duration.zero;

    switch (parts.length) {
      case 3:
        return Duration(
          hours: parts[0]!,
          minutes: parts[1]!,
          seconds: parts[2]!,
        );
      case 2:
        return Duration(minutes: parts[0]!, seconds: parts[1]!);
      case 1:
        return Duration(seconds: parts[0]!);
      default:
        return Duration.zero;
    }
  }

  /// Starts a work order and begins tracking elapsed time
  Future<bool> startWorkOrder(int id, String? formattedDuration) async {
    try {
      final result = await _service.startWorkOrder(id);
      if (result["success"] == true) {
        final alreadyElapsed = parseFormattedDuration(formattedDuration);
        _timerManager.start(id, alreadyElapsed);
        await loadWorkOrders();
        return true;
      } else {
        _alertMessage = result["error"];
        notifyListeners();
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Pauses a running work order and stops timer tracking
  Future<bool> pauseWorkOrder(int id) async {
    try {
      final result = await _service.pauseWorkOrder(id);
      if (result["success"] == true) {
        _timerManager.pause(id);
        await loadWorkOrders();
        return true;
      } else {
        _alertMessage = result["error"];
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Finishes/completes a work order and stops timer
  Future<bool> finishWorkOrder(int id) async {
    try {
      final result = await _service.stopWorkOrder(id);
      if (result["success"] == true) {
        _timerManager.stop(id);
        await loadWorkOrders();
        return true;
      } else {
        _alertMessage = result["error"];
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Initializes the provider: loads session, reference data, and initial work orders
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.initializeClient();
      await loadWorkCenters();
      await loadLostReasons();
      await loadWorkOrders(reset: true);
    } catch (e) {
      _errorMessage = 'Failed to initialize: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads all available work centers from service
  Future<void> loadWorkCenters() async {
    try {
      _workCenters = await _service.fetchWorkCenter();
    } catch (e) {}
  }

  /// Loads all lost time reasons from service
  Future<void> loadLostReasons() async {
    try {
      _lostReasons = await _service.loadLostReason();
    } catch (e) {}
  }

  /// Builds domain filter for a single status value
  List<dynamic> buildStatusDomain(String status) {
    final today = DateTime.now().toIso8601String().split('T').first;

    switch (status) {
      case 'progress':
        return [
          ['state', '=', 'progress'],
        ];

      case 'ready':
        return [
          ['state', '=', 'ready'],
        ];

      case 'waiting':
        return [
          ['state', '=', 'waiting'],
        ];

      case 'pending':
        return [
          '&',
          ['state', '=', 'pending'],
          ['production_state', '!=', 'draft'],
        ];

      case 'draft':
        return [
          '&',
          ['state', '=', 'pending'],
          ['production_state', '=', 'draft'],
        ];

      case 'finished':
        return [
          ['state', '=', 'done'],
        ];

      case 'late':
        return [
          '&',
          ['date_start', '<', today],
          ['state', '=', 'ready'],
        ];

      default:
        return [];
    }
  }

  /// Builds combined OR domain for multiple selected statuses
  List<dynamic> buildMultiStatusDomain(List<String> statuses) {
    if (statuses.isEmpty) return [];

    final List<List<dynamic>> domains = statuses
        .map(buildStatusDomain)
        .toList();

    if (domains.length == 1) {
      return domains.first;
    }

    final result = <dynamic>[];

    for (int i = 0; i < domains.length - 1; i++) {
      result.add('|');
    }

    for (final d in domains) {
      result.addAll(d);
    }

    return result;
  }

  /// Loads work orders (paginated) with current filters/search/grouping
  Future<void> loadWorkOrders({bool reset = false}) async {
    if (reset) {
      _currentPage = 0;
      _workOrders = [];
    }

    _isPaginationLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final domain = <dynamic>[];

      if (_selectedStatuses.isNotEmpty) {
        domain.addAll(buildMultiStatusDomain(_selectedStatuses));
      }

      if (_selectedWorkCenterId != null) {
        domain.add(['workcenter_id', '=', _selectedWorkCenterId]);
      }

      final paginated = await _service.fetchWorkOrdersPaginated(
        page: _currentPage,
        search: _searchText,
        domain: domain,
      );

      _workOrders = paginated.items;
      _totalCount = paginated.totalCount;
    } catch (e) {
      _errorMessage = 'Failed to load work orders. Please try again.';
    } finally {
      _isPaginationLoading = false;
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Updates search text, resets pagination, and triggers reload
  void setSearchText(String value) {
    if (_searchText == value) return;

    _searchText = value;
    _currentPage = 0;
    _isSearching = true;
    _workOrders = [];

    notifyListeners();

    loadWorkOrders(reset: true).then((_) {
      _isSearching = false;
      notifyListeners();
    });
  }

  /// Sets active status filters and reloads data
  void setStatusFilter(List<String> statuses) {
    _selectedStatuses = statuses;
    _currentPage = 0;
    notifyListeners();
    loadWorkOrders();
  }

  /// Sets work center filter and reloads data
  void setWorkCenterFilter(int? workCenterId) {
    _selectedWorkCenterId = workCenterId;
    _currentPage = 0;
    notifyListeners();
  }

  /// Moves to the next page if available
  void nextPage() {
    if (!hasNextPage) return;
    _currentPage++;
    loadWorkOrders();
  }

  /// Moves to the previous page if available
  void previousPage() {
    if (_currentPage <= 0) return;
    _currentPage--;
    loadWorkOrders();
  }

  bool get hasNextPage =>
      (_currentPage + 1) * WorkOrderService.itemsPerPage < _totalCount;

  bool get hasPreviousPage => _currentPage > 0;
}
