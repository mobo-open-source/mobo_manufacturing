import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../Dashboard/services/settings_storage_service.dart';
import '../../service/mo_form_service.dart';
import 'mo_form_event.dart';
import 'mo_form_state.dart';

/// Business logic component (BLOC) that manages the state of a Manufacturing Order form.
///
/// Handles:
/// - Loading MO data and related entities (moves, work orders, BOMs, users, etc.)
/// - Updating manufacturing order header fields
/// - Work order lifecycle (start / pause / stop)
/// - Real-time duration tracking for running work orders
/// - Actions: confirm, cancel, produce all, scrap, unbuild
/// - Component consumption / product move modifications
class MoFormBloc extends Bloc<MoFormEvent, MoFormState> {
  final MoFormService moFormService;
  final SettingsStorageService settingsStorageService;
  Timer? _globalTimer;
  final Map<int, Timer> _workOrderTimers = {};

  MoFormBloc(this.moFormService, this.settingsStorageService)
    : super(const MoFormState()) {
    on<LoadMoFormData>(_onLoadMoFormData);
    on<UpdateManufacturingDetails>(_onUpdateManufacturingDetails);
    on<StartWorkOrder>(_onStartWorkOrder);
    on<PauseWorkOrder>(_onPauseWorkOrder);
    on<StopWorkOrder>(_onStopWorkOrder);
    on<BlockWorkOrder>(_onBlockWorkOrder);
    on<UnblockWorkOrder>(_onUnblockWorkOrder);
    on<ScrapMo>(_onScrapMo);
    on<UnbuildMo>(_onUnbuildMo);
    on<CancelMo>(_onCancelMo);
    on<ConfirmMo>(_onConfirmMo);
    on<ProduceAllMo>(_onProduceAllMo);
    on<UpdateProductMove>(_onUpdateProductMove);
    on<AddProductToLine>(_onAddProductToLine);
    on<DeleteProductMove>(_onDeleteProductMove);
    on<UpdateConsume>(_onUpdateConsume);
    on<UpdateEditingField>(_onUpdateEditingField);
    on<TickWorkOrder>(_onTickWorkOrder);
  }

  /// Loads all data required to display and edit a manufacturing order.
  Future<void> _onLoadMoFormData(
    LoadMoFormData event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await settingsStorageService.initialize();
      await moFormService.initializeClient();

      final moItem = await moFormService.loadMo(event.moId);
      final moveProducts = await moFormService.loadProductMoves(event.moId);
      final products = await moFormService.loadProducts();
      final productScrap = await moFormService.loadProductScrap(
        moItem,
        moveProducts,
      );
      final workOrders = await moFormService.loadWorkOrders(event.moId);
      final lostReason = await moFormService.loadLostReason();
      final scrapProduct = await moFormService.loadStockScrap(event.moId);
      final unbuildOrders = await moFormService.loadUnbuildOrders(event.moId);
      final billOfMaterial = await moFormService.loadBom();
      final users = await moFormService.loadUsers();

      _initializeWorkOrderTimers(emit);

      emit(
        state.copyWith(
          moItem: moItem,
          moveProducts: moveProducts,
          products: products,
          productScrap: productScrap,
          workOrders: workOrders,
          lostReason: lostReason,
          scrapProduct: scrapProduct,
          unbuildOrders: unbuildOrders,
          billOfMaterial: billOfMaterial,
          users: users,
          isLoading: false,
          enableManufacturingDeadline:
              settingsStorageService.getBool('enableManufacturingDeadline') ??
              true,
          enableOrderDeadline:
              settingsStorageService.getBool('enableOrderDate') ?? true,
          showOverviewSmartTab:
              settingsStorageService.getBool('showOverviewSmartTab') ?? true,
          showProductMoveSmartTab:
              settingsStorageService.getBool('showProductMoveSmartTab') ?? true,
          showTraceabilitySmartTab:
              settingsStorageService.getBool('showTraceabilitySmartTab') ??
              true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// (Re)initializes timers for any work orders that were previously started.
  /// Called after initial data load.
  void _initializeWorkOrderTimers(Emitter<MoFormState> emit) {
    for (var timer in _workOrderTimers.values) {
      timer.cancel();
    }
    _workOrderTimers.clear();

    final activeWorkOrders = state.workOrderStarted.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (activeWorkOrders.isNotEmpty) {
      _startGlobalTimer(emit);
    }
  }

  /// Starts (or restarts) the global periodic timer that ticks every second
  /// to update durations of all running work orders.
  void _startGlobalTimer(Emitter<MoFormState> emit) {
    _globalTimer?.cancel();

    _globalTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(TickWorkOrder());
    });
  }

  /// Stops the global timer if no more work orders are running.
  void _stopGlobalTimer() {
    _globalTimer?.cancel();
    _globalTimer = null;
  }

  /// Core real-time duration logic:
  ///   • Adds 1 second to every work order marked as started
  ///   • Emits new durations map only if something changed
  ///   • Automatically stops global timer when no active work orders remain
  void _onTickWorkOrder(TickWorkOrder event, Emitter<MoFormState> emit) {
    final updatedDurations = <int, Duration>{};
    bool hasChanges = false;

    for (final entry in state.workOrderStarted.entries) {
      if (entry.value) {
        final currentDuration =
            state.workOrderDurations[entry.key] ?? Duration.zero;
        updatedDurations[entry.key] =
            currentDuration + const Duration(seconds: 1);
        hasChanges = true;
      }
    }

    if (hasChanges) {
      final currentDurations = Map<int, Duration>.from(
        state.workOrderDurations,
      );
      updatedDurations.forEach((key, value) {
        currentDurations[key] = value;
      });

      emit(state.copyWith(workOrderDurations: currentDurations));
    }

    final activeWorkOrders = state.workOrderStarted.entries
        .where((entry) => entry.value)
        .isNotEmpty;

    if (!activeWorkOrders) {
      _stopGlobalTimer();
    }
  }

  /// Prepares/resumes timer tracking for one specific work order.
  /// Currently mainly ensures global timer is running.
  void _startWorkOrderTimer(int workOrderId, Emitter<MoFormState> emit) {
    _workOrderTimers[workOrderId]?.cancel();
    _workOrderTimers.remove(workOrderId);

    _startGlobalTimer(emit);
  }

  /// Pauses timer for one work order:
  /// - calculates elapsed time since last start
  /// - adds it to total duration
  /// - removes start time & running flag
  void _pauseWorkOrderTimer(int workOrderId, Emitter<MoFormState> emit) {
    final startTime = state.workOrderStartTimes[workOrderId];
    if (startTime != null) {
      final elapsed = DateTime.now().difference(startTime);
      final currentDuration =
          state.workOrderDurations[workOrderId] ?? Duration.zero;
      final totalDuration = currentDuration + elapsed;

      final updatedDurations = Map<int, Duration>.from(state.workOrderDurations)
        ..[workOrderId] = totalDuration;

      final updatedStarted = Map<int, bool>.from(state.workOrderStarted)
        ..[workOrderId] = false;

      final updatedStartTimes = Map<int, DateTime>.from(
        state.workOrderStartTimes,
      )..remove(workOrderId);

      emit(
        state.copyWith(
          workOrderDurations: updatedDurations,
          workOrderStarted: updatedStarted,
          workOrderStartTimes: updatedStartTimes,
        ),
      );
    }

    final activeWorkOrders = state.workOrderStarted.entries
        .where((entry) => entry.value)
        .isNotEmpty;

    if (!activeWorkOrders) {
      _stopGlobalTimer();
    }
  }

  /// Fully stops timer tracking for one work order (usually after marking Done).
  void _stopWorkOrderTimer(int workOrderId, Emitter<MoFormState> emit) {
    _workOrderTimers[workOrderId]?.cancel();
    _workOrderTimers.remove(workOrderId);

    final updatedStarted = Map<int, bool>.from(state.workOrderStarted)
      ..[workOrderId] = false;

    final updatedStartTimes = Map<int, DateTime>.from(state.workOrderStartTimes)
      ..remove(workOrderId);

    emit(
      state.copyWith(
        workOrderStarted: updatedStarted,
        workOrderStartTimes: updatedStartTimes,
      ),
    );

    final activeWorkOrders = state.workOrderStarted.entries
        .where((entry) => entry.value)
        .isNotEmpty;

    if (!activeWorkOrders) {
      _stopGlobalTimer();
    }
  }

  // ────────────────────────────────────────────────
  //          Work Order Action Handlers
  // ────────────────────────────────────────────────

  /// Calls backend to start work order → updates local running state → starts timer
  Future<void> _onStartWorkOrder(
    StartWorkOrder event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      await moFormService.startWorkOrder(event.moId, event.workOrderId);

      _startWorkOrderTimer(event.workOrderId, emit);

      final updatedStarted = Map<int, bool>.from(state.workOrderStarted)
        ..[event.workOrderId] = true;

      final updatedStartTimes = Map<int, DateTime>.from(
        state.workOrderStartTimes,
      )..[event.workOrderId] = DateTime.now();

      final workOrders = await moFormService.loadWorkOrders(event.moId);

      emit(
        state.copyWith(
          workOrders: workOrders,
          workOrderStarted: updatedStarted,
          workOrderStartTimes: updatedStartTimes,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Pauses work order on backend → updates accumulated duration → stops timer counting
  Future<void> _onPauseWorkOrder(
    PauseWorkOrder event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      await moFormService.pauseWorkOrder(event.moId, event.workOrderId);

      _pauseWorkOrderTimer(event.workOrderId, emit);

      final workOrders = await moFormService.loadWorkOrders(event.moId);

      emit(state.copyWith(workOrders: workOrders, isLoading: false));

    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Marks work order done on backend → clears timer state
  Future<void> _onStopWorkOrder(
    StopWorkOrder event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      await moFormService.stopWorkOrder(event.moId, event.workOrderId);

      _stopWorkOrderTimer(event.workOrderId, emit);

      final workOrders = await moFormService.loadWorkOrders(event.moId);

      emit(state.copyWith(workOrders: workOrders, isLoading: false));

    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  // ────────────────────────────────────────────────
  //          MO Header & Lifecycle Actions
  // ────────────────────────────────────────────────

  /// Updates core fields of the manufacturing order (product, qty, dates, responsible, BOM…)
  Future<void> _onUpdateManufacturingDetails(
    UpdateManufacturingDetails event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.updateManufacturingDetails(
        event.updatedDetails,
        event.moId,
      );
      if (success) {
        final moItem = await moFormService.loadMo(event.moId);
        emit(
          state.copyWith(moItem: moItem, isLoading: false, editingField: null),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to update manufacturing details',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Blocks a specific work order (typically when it encounters an issue at a work center).
  ///
  /// - Calls backend to register the block with reason & description
  /// - On success: adds work order ID to the local `blockedWorkOrderIds` set
  /// - Reloads nothing automatically (UI usually refreshes via other means)
  Future<void> _onBlockWorkOrder(
    BlockWorkOrder event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.blockWorkOrder(
        event.moId,
        event.workOrderId,
        event.workCenterId!,
        event.reasonId,
        event.description!,
      );
      if (success) {
        final blockedWorkOrderIds = Set<int>.from(state.blockedWorkOrderIds)
          ..add(event.workOrderId);
        emit(
          state.copyWith(
            blockedWorkOrderIds: blockedWorkOrderIds,
            isLoading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to block work order',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Removes the block status from a work order.
  ///
  /// - Calls backend to unblock the work order at the given work center
  /// - On success: removes work order ID from the local `blockedWorkOrderIds` set
  Future<void> _onUnblockWorkOrder(
    UnblockWorkOrder event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.unblockWorkOrder(
        event.moId,
        event.workOrderId,
        event.workCenterId!,
      );
      if (success) {
        final blockedWorkOrderIds = Set<int>.from(state.blockedWorkOrderIds)
          ..remove(event.workOrderId);
        emit(
          state.copyWith(
            blockedWorkOrderIds: blockedWorkOrderIds,
            isLoading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to unblock work order',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Registers scrapped quantity for one or more components/materials of the MO.
  ///
  /// - Sends scrap details to backend
  /// - On success: reloads the main MO record + updated scrap records
  Future<void> _onScrapMo(ScrapMo event, Emitter<MoFormState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.scrapMo(event.scrapDetails);
      if (success) {
        final moId = event.scrapDetails['production_id'] as int;
        final moItem = await moFormService.loadMo(moId);
        final scrapProduct = await moFormService.loadStockScrap(moId);
        emit(
          state.copyWith(
            moItem: moItem,
            scrapProduct: scrapProduct,
            isLoading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to scrap manufacturing order',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Marks the entire manufacturing order as fully produced ("Produce All").
  ///
  /// - Triggers backend produce-all action
  /// - On success: reloads the updated MO record (usually moves state to done)
  Future<void> _onProduceAllMo(
    ProduceAllMo event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.produceAll(event.moItem[0]['id']);

      if (success) {
        final moId = int.parse(event.moItem[0]['id'].toString());
        final moItem = await moFormService.loadMo(moId);
        emit(state.copyWith(moItem: moItem, isLoading: false));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to mark as done to manufacturing order',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Cancels the manufacturing order.
  ///
  /// - Calls backend cancel endpoint
  /// - On success: reloads MO to reflect cancelled state
  Future<void> _onCancelMo(CancelMo event, Emitter<MoFormState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.cancelMo(event.moItem[0]['id']);
      if (success) {
        final moId = int.parse(event.moItem[0]['id'].toString());
        final moItem = await moFormService.loadMo(moId);
        emit(state.copyWith(moItem: moItem, isLoading: false));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to cancel manufacturing order',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Confirms the manufacturing order (usually from Draft → Confirmed).
  ///
  /// - Triggers backend confirmation
  /// - On success: reloads MO to show updated state & possibly generated work orders
  Future<void> _onConfirmMo(ConfirmMo event, Emitter<MoFormState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.confirmMo(event.moItem[0]['id']);
      if (success) {
        final moId = int.parse(event.moItem[0]['id'].toString());
        final moItem = await moFormService.loadMo(moId);
        emit(state.copyWith(moItem: moItem, isLoading: false));
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to confirm manufacturing order',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Performs an unbuild operation (reverse production / disassemble finished goods).
  ///
  /// - Calls backend unbuild action
  /// - On success: reloads MO + list of unbuild orders
  Future<void> _onUnbuildMo(UnbuildMo event, Emitter<MoFormState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      final success = await moFormService.unbuildMo(event.moItem);
      if (success) {
        final moId = int.parse(event.moItem[0]['id'].toString());
        final moItem = await moFormService.loadMo(moId);
        final unbuildOrders = await moFormService.loadUnbuildOrders(moId);
        emit(
          state.copyWith(
            moItem: moItem,
            unbuildOrders: unbuildOrders,
            isLoading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to unbuild manufacturing order',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Updates an existing stock move / product line (change product, quantity, to-consume flag…).
  ///
  /// - Sends update to backend
  /// - Reloads full list of product moves
  Future<void> _onUpdateProductMove(
    UpdateProductMove event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      await moFormService.updateProductMove(
        event.productMoveId,
        event.productId,
        event.productName,
        event.quantity,
        event.toConsume,
      );
      final moId = state.moItem.isNotEmpty
          ? int.parse(state.moItem[0]['id'].toString())
          : 0;
      final moveProducts = await moFormService.loadProductMoves(moId);
      emit(state.copyWith(moveProducts: moveProducts, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Adds a new component/product line to the manufacturing order.
  ///
  /// - Creates new stock move via backend
  /// - Reloads updated product moves list
  Future<void> _onAddProductToLine(
    AddProductToLine event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      await moFormService.addProductToLine(
        event.moId,
        event.productId,
        event.productName,
        event.toConsume,
        event.quantity,
        event.moProductId,
      );
      final moveProducts = await moFormService.loadProductMoves(event.moId);
      emit(state.copyWith(moveProducts: moveProducts, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Removes a product/component line (stock move) from the manufacturing order.
  ///
  /// - Deletes via backend
  /// - Reloads updated product moves list
  Future<void> _onDeleteProductMove(
    DeleteProductMove event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      await moFormService.deleteProductMove(event.productMoveId);
      final moId = state.moItem.isNotEmpty
          ? int.parse(state.moItem[0]['id'].toString())
          : 0;
      final moveProducts = await moFormService.loadProductMoves(moId);
      emit(state.copyWith(moveProducts: moveProducts, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Updates the consumed / picked quantity for a specific component move.
  ///
  /// Commonly used during production to record real consumption.
  /// Reloads the full product moves list afterward.
  Future<void> _onUpdateConsume(
    UpdateConsume event,
    Emitter<MoFormState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));
    try {
      await moFormService.initializeClient();
      await moFormService.updateConsume(event.productMoveId, event.picked);
      final moId = state.moItem.isNotEmpty
          ? int.parse(state.moItem[0]['id'].toString())
          : 0;
      final moveProducts = await moFormService.loadProductMoves(moId);
      emit(state.copyWith(moveProducts: moveProducts, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  /// Records which field is currently being edited (used mainly for UI focus/highlighting)
  void _onUpdateEditingField(
    UpdateEditingField event,
    Emitter<MoFormState> emit,
  ) {
    emit(state.copyWith(editingField: event.field));
  }

  /// Cleans up all timers when the bloc is being closed (important to prevent memory leaks)
  @override
  Future<void> close() {
    _globalTimer?.cancel();
    for (var timer in _workOrderTimers.values) {
      timer.cancel();
    }
    _workOrderTimers.clear();
    return super.close();
  }
}
