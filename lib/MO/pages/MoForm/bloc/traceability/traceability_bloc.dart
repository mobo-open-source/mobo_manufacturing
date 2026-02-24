import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/stock_move.dart';
import '../../service/mo_form_service.dart';
import 'traceability_event.dart';
import 'traceability_state.dart';

/// BLoC responsible for loading traceability-related data for a Manufacturing Order.
///
/// This bloc prepares the detailed information needed for the Traceability Report page:
/// • Product details of the main produced item
/// • Detailed move lines (including lot/serial numbers) for each component/raw material move
///
/// It fetches data from Odoo via `MoFormService` and emits:
/// - Loading state while fetching
/// - Loaded state with product details + move lines
/// - Error state on failure
class TraceabilityBloc extends Bloc<TraceabilityEvent, TraceabilityState> {
  final List<dynamic> moItem;
  final List<StockMove> moveProducts;

  TraceabilityBloc({required this.moItem, required this.moveProducts})
    : super(TraceabilityInitial()) {
    on<LoadTraceabilityEvent>(_onLoadTraceability);
  }

  /// Handles the initial loading of traceability data.
  ///
  /// Flow:
  /// 1. Emits loading state
  /// 2. Initializes Odoo service client
  /// 3. Loads detailed product info for the main produced item
  /// 4. Loads detailed move lines for each component stock move
  /// 5. Emits loaded state with both product details and move lines
  /// 6. On any error (network, Odoo failure, parsing issue) → emits error state
  Future<void> _onLoadTraceability(
    LoadTraceabilityEvent event,
    Emitter<TraceabilityState> emit,
  ) async {
    emit(TraceabilityLoading());

    try {
      final odooMoService = MoFormService();
      await odooMoService.initializeClient();

      // ─── Load main produced product details ─────────────────────────────
      final productDetails = await odooMoService.loadProductDetails(
        moItem[0]['product_id'][0],
      );

      // ─── Load move lines for all component moves ────────────────────────
      final moveLines = <dynamic>[];
      for (var move in moveProducts) {
        final lines = await odooMoService.loadProductsMoveLine(move.id);
        moveLines.add(lines);
      }

      emit(
        TraceabilityLoaded(
          productDetails: productDetails,
          moveLines: moveLines,
        ),
      );
    } catch (e) {
      emit(TraceabilityError(message: e.toString()));
    }
  }
}
