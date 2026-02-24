import 'package:equatable/equatable.dart';

import '../../models/bom.dart';
import '../../models/lost_reason.dart';
import '../../models/mo_work_order.dart';
import '../../models/product.dart';
import '../../models/stock_move.dart';
import '../../models/user_model.dart';

/// Immutable state class for the Manufacturing Order (MO) form screen.
///
/// Holds:
/// • Core MO data and related entities (products, components, work orders, BOMs, users...)
/// • UI control flags (loading, editing mode, visibility toggles)
/// • Real-time work order timer information
/// • Selection states for dialogs/dropdowns (scrap, reasons, products...)
///
/// Uses `Equatable` for efficient state comparison in BLoC.
class MoFormState extends Equatable {
  final List<dynamic> moItem;
  final List<StockMove> moveProducts;
  final List<Product> products;
  final List<Product> productScrap;
  final List<LostReason> lostReason;
  final List<MoWorkOrder> workOrders;
  final List<Bom> billOfMaterial;
  final List<UserModel> users;
  final List<dynamic> unbuildOrders;
  final List<dynamic> scrapProduct;
  final bool isLoading;
  final String errorMessage;
  final int? selectedPartnerId;
  final int? selectedMo;
  final String? selectedMoName;
  final int? selectedReason;
  final String? selectedReasonName;
  final bool isStarted;
  final Duration realDuration;
  final int? activeWorkOrderId;
  final bool isUnblock;
  final int? blockedWorkOrderId;
  final Set<int> blockedWorkOrderIds;
  final int? selectedProductScrap;
  final String? selectedProductScrapName;
  final int? selectedProduct;
  final String? selectedProductName;
  final double quantity;
  final bool replenishQty;
  final bool enableManufacturingDeadline;
  final bool enableOrderDeadline;
  final bool showOverviewSmartTab;
  final bool showProductMoveSmartTab;
  final bool showTraceabilitySmartTab;
  final String? editingField;
  final int? updatedProduct;
  final int? updatedBom;
  final int? updatedUser;
  final String? updatedQty;
  final DateTime? updatedScheduleDate;
  final DateTime? updatedEndDate;
  final Map<int, bool> workOrderStarted;
  final Map<int, Duration> workOrderDurations;
  final Map<int, DateTime> workOrderStartTimes;

  const MoFormState({
    this.moItem = const [],
    this.moveProducts = const [],
    this.products = const [],
    this.productScrap = const [],
    this.lostReason = const [],
    this.workOrders = const [],
    this.billOfMaterial = const [],
    this.users = const [],
    this.unbuildOrders = const [],
    this.scrapProduct = const [],
    this.isLoading = false,
    this.errorMessage = '',
    this.selectedPartnerId,
    this.selectedMo,
    this.selectedMoName,
    this.selectedReason,
    this.selectedReasonName,
    this.isStarted = false,
    this.realDuration = Duration.zero,
    this.activeWorkOrderId,
    this.isUnblock = false,
    this.blockedWorkOrderId,
    this.blockedWorkOrderIds = const {},
    this.selectedProductScrap,
    this.selectedProductScrapName,
    this.selectedProduct,
    this.selectedProductName,
    this.quantity = 1.0,
    this.replenishQty = false,
    this.enableManufacturingDeadline = true,
    this.enableOrderDeadline = true,
    this.showOverviewSmartTab = true,
    this.showProductMoveSmartTab = true,
    this.showTraceabilitySmartTab = true,
    this.editingField,
    this.updatedProduct,
    this.updatedBom,
    this.updatedUser,
    this.updatedQty,
    this.updatedScheduleDate,
    this.updatedEndDate,
    this.workOrderStarted = const {},
    this.workOrderDurations = const {},
    this.workOrderStartTimes = const {},
  });

  /// Creates a new state instance with some fields overridden.
  ///
  /// Standard immutable state pattern — preserves unchanged fields.
  MoFormState copyWith({
    List<dynamic>? moItem,
    List<StockMove>? moveProducts,
    List<Product>? products,
    List<Product>? productScrap,
    List<LostReason>? lostReason,
    List<MoWorkOrder>? workOrders,
    List<Bom>? billOfMaterial,
    List<UserModel>? users,
    List<dynamic>? unbuildOrders,
    List<dynamic>? scrapProduct,
    bool? isLoading,
    String? errorMessage,
    int? selectedPartnerId,
    int? selectedMo,
    String? selectedMoName,
    int? selectedReason,
    String? selectedReasonName,
    bool? isStarted,
    Duration? realDuration,
    int? activeWorkOrderId,
    bool? isUnblock,
    int? blockedWorkOrderId,
    Set<int>? blockedWorkOrderIds,
    int? selectedProductScrap,
    String? selectedProductScrapName,
    int? selectedProduct,
    String? selectedProductName,
    double? quantity,
    bool? replenishQty,
    bool? enableManufacturingDeadline,
    bool? enableOrderDeadline,
    bool? showOverviewSmartTab,
    bool? showProductMoveSmartTab,
    bool? showTraceabilitySmartTab,
    String? editingField,
    int? updatedProduct,
    int? updatedBom,
    int? updatedUser,
    String? updatedQty,
    DateTime? updatedScheduleDate,
    DateTime? updatedEndDate,
    Map<int, bool>? workOrderStarted,
    Map<int, Duration>? workOrderDurations,
    Map<int, DateTime>? workOrderStartTimes,
  }) {
    return MoFormState(
      moItem: moItem ?? this.moItem,
      moveProducts: moveProducts ?? this.moveProducts,
      products: products ?? this.products,
      productScrap: productScrap ?? this.productScrap,
      lostReason: lostReason ?? this.lostReason,
      workOrders: workOrders ?? this.workOrders,
      billOfMaterial: billOfMaterial ?? this.billOfMaterial,
      users: users ?? this.users,
      unbuildOrders: unbuildOrders ?? this.unbuildOrders,
      scrapProduct: scrapProduct ?? this.scrapProduct,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedPartnerId: selectedPartnerId ?? this.selectedPartnerId,
      selectedMo: selectedMo ?? this.selectedMo,
      selectedMoName: selectedMoName ?? this.selectedMoName,
      selectedReason: selectedReason ?? this.selectedReason,
      selectedReasonName: selectedReasonName ?? this.selectedReasonName,
      isStarted: isStarted ?? this.isStarted,
      realDuration: realDuration ?? this.realDuration,
      activeWorkOrderId: activeWorkOrderId ?? this.activeWorkOrderId,
      isUnblock: isUnblock ?? this.isUnblock,
      blockedWorkOrderId: blockedWorkOrderId ?? this.blockedWorkOrderId,
      blockedWorkOrderIds: blockedWorkOrderIds ?? this.blockedWorkOrderIds,
      selectedProductScrap: selectedProductScrap ?? this.selectedProductScrap,
      selectedProductScrapName:
          selectedProductScrapName ?? this.selectedProductScrapName,
      selectedProduct: selectedProduct ?? this.selectedProduct,
      selectedProductName: selectedProductName ?? this.selectedProductName,
      quantity: quantity ?? this.quantity,
      replenishQty: replenishQty ?? this.replenishQty,
      enableManufacturingDeadline:
          enableManufacturingDeadline ?? this.enableManufacturingDeadline,
      enableOrderDeadline: enableOrderDeadline ?? this.enableOrderDeadline,
      showOverviewSmartTab: showOverviewSmartTab ?? this.showOverviewSmartTab,
      showProductMoveSmartTab:
          showProductMoveSmartTab ?? this.showProductMoveSmartTab,
      showTraceabilitySmartTab:
          showTraceabilitySmartTab ?? this.showTraceabilitySmartTab,
      editingField: editingField ?? this.editingField,
      updatedProduct: updatedProduct ?? this.updatedProduct,
      updatedBom: updatedBom ?? this.updatedBom,
      updatedUser: updatedUser ?? this.updatedUser,
      updatedQty: updatedQty ?? this.updatedQty,
      updatedScheduleDate: updatedScheduleDate ?? this.updatedScheduleDate,
      updatedEndDate: updatedEndDate ?? this.updatedEndDate,
      workOrderStarted: workOrderStarted ?? this.workOrderStarted,
      workOrderDurations: workOrderDurations ?? this.workOrderDurations,
      workOrderStartTimes: workOrderStartTimes ?? this.workOrderStartTimes,
    );
  }

  /// Checks whether the given work order is currently running (timer active).
  bool isWorkOrderStarted(int workOrderId) =>
      workOrderStarted[workOrderId] ?? false;

  /// Returns the current real-time duration of a work order.
  ///
  /// If the work order is running, adds the time elapsed since last start
  /// to the accumulated duration.
  Duration getWorkOrderDuration(int workOrderId) {
    final duration = workOrderDurations[workOrderId] ?? Duration.zero;
    final startTime = workOrderStartTimes[workOrderId];

    if (startTime != null && isWorkOrderStarted(workOrderId)) {
      return duration + DateTime.now().difference(startTime);
    }
    return duration;
  }

  @override
  List<Object?> get props => [
    moItem,
    moveProducts,
    products,
    productScrap,
    lostReason,
    workOrders,
    billOfMaterial,
    users,
    unbuildOrders,
    scrapProduct,
    isLoading,
    errorMessage,
    selectedPartnerId,
    selectedMo,
    selectedMoName,
    selectedReason,
    selectedReasonName,
    isStarted,
    realDuration,
    activeWorkOrderId,
    isUnblock,
    blockedWorkOrderId,
    blockedWorkOrderIds,
    selectedProductScrap,
    selectedProductScrapName,
    selectedProduct,
    selectedProductName,
    quantity,
    replenishQty,
    enableManufacturingDeadline,
    enableOrderDeadline,
    showOverviewSmartTab,
    showProductMoveSmartTab,
    showTraceabilitySmartTab,
    editingField,
    updatedProduct,
    updatedBom,
    updatedUser,
    updatedQty,
    updatedScheduleDate,
    updatedEndDate,
    workOrderStarted,
    workOrderDurations,
    workOrderStartTimes,
  ];
}
