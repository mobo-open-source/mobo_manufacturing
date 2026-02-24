import 'package:flutter_bloc/flutter_bloc.dart';

import '../service/mo_list_service.dart';
import 'create_mo_event.dart';
import 'create_mo_state.dart';

/// BLoC responsible for managing the state and business logic of creating
/// a new Manufacturing Order (MO) in the application.
///
/// Handles two main events:
/// - [LoadCreateMOData] → loads reference data (products, BOMs, users)
/// - [CreateManufacturingOrder] → validates and submits the new MO to the backend
///
/// This BLoC interacts with [MoListService] for all data operations (fetching
/// and creation).
class CreateMOBloC extends Bloc<CreateMOEvent, CreateMOState> {
  final MoListService _moListService;

  /// Initializes the BLoC with the required service and starts in the
  /// initial state ([CreateMOState.initial()]).
  ///
  /// Registers event handlers for the two supported events.
  CreateMOBloC(this._moListService) : super(CreateMOState.initial()) {
    on<LoadCreateMOData>(_onLoadCreateMOData);
    on<CreateManufacturingOrder>(_onCreateManufacturingOrder);
  }

  /// Handler for [LoadCreateMOData] event.
  ///
  /// Loads essential reference data needed to create a manufacturing order:
  ///   - Products
  ///   - Bills of Materials (BOMs)
  ///   - Users (for responsible person selection)
  ///
  /// Emits loading state → success with data → or error state.
  Future<void> _onLoadCreateMOData(
      LoadCreateMOData event,
      Emitter<CreateMOState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));

    try {
      final products = await _moListService.loadProducts();
      final boms = await _moListService.loadBom();
      final users = await _moListService.loadUsers();

      emit(state.copyWith(
        isLoading: false,
        products: products,
        billOfMaterial: boms,
        users: users,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load data: ${e.toString()}',
      ));
    }
  }

  /// Handler for [CreateManufacturingOrder] event.
  ///
  /// Responsible for creating a new Manufacturing Order in the backend.
  ///
  /// Flow:
  /// 1. Sets loading state
  /// 2. Performs basic client-side validation (currently only checks product)
  /// 3. Calls the service to create the MO with the complete payload
  /// 4. On success → emits success state (usually triggers navigation back)
  /// 5. On failure → emits error message
  ///
  /// The [moData] map is expected to contain:
  /// - 'moCreate': main MO fields (product_id, product_qty, bom_id, user_id, dates...)
  /// - 'productData': list of components to consume
  /// - 'workOrderData': list of work orders / operations
  Future<void> _onCreateManufacturingOrder(
      CreateManufacturingOrder event,
      Emitter<CreateMOState> emit,
      ) async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));

    try {

      if (event.moData['moCreate']['product_id'] == null) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Product is required',
        ));
        return;
      }

      final success = await _moListService.createNewManufacturingOrder(event.moData);

      if (success) {
        emit(state.copyWith(
          isLoading: false,
          isSuccess: true,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to create Manufacturing Order',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Error creating Manufacturing Order: ${e.toString()}',
      ));
    }
  }
}