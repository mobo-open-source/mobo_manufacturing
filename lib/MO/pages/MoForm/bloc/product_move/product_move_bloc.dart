import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoForm/bloc/product_move/product_move_event.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoForm/bloc/product_move/product_move_state.dart';
 import '../../models/stock_move.dart';
import '../../service/mo_form_service.dart';

/// BLoC responsible for loading and managing detailed stock move line information
/// for the Product Move / Inventory Moves page of a Manufacturing Order (MO).
///
/// Responsibilities:
/// • Loads detailed move lines (including lot/serial numbers) for:
///   - The finished product move (from `finished_move_line_ids`)
///   - All component/raw material moves (from `moveProducts`)
/// • Emits loading → loaded (with move lines) or error states
/// • Uses `MoFormService` to fetch move line data from Odoo
class ProductMoveBloc extends Bloc<ProductMoveEvent, ProductMoveState> {
  final List<dynamic> moItem;
  final List<StockMove> moveProducts;

  ProductMoveBloc({required this.moItem, required this.moveProducts})
    : super(ProductMoveInitial()) {
    on<LoadProductMoveEvent>(_onLoadProductMoves);
  }

  /// Handles the initial loading of detailed move line records.
  ///
  /// Flow:
  /// 1. Emits loading state
  /// 2. Initializes Odoo service client
  /// 3. Loads move lines for the finished product (via `finished_move_line_ids`)
  /// 4. Loads move lines for each component move (via `move.id`)
  /// 5. Combines all move lines and emits loaded state
  /// 6. On any error (network, parsing, Odoo failure) → emits error state
  Future<void> _onLoadProductMoves(
    LoadProductMoveEvent event,
    Emitter<ProductMoveState> emit,
  ) async {
    emit(ProductMoveLoading());

    try {
      final odooMoService = MoFormService();
      await odooMoService.initializeClient();

      // ─── Load finished product move lines ───────────────────────────────
      final finishedMoveLineIds =
          moItem[0]['finished_move_line_ids'] as List<dynamic>;
      final finishedMoveLines = <dynamic>[];

      for (var lineId in finishedMoveLineIds) {
        final lines = await odooMoService.loadProductsMoveLine(lineId);
        finishedMoveLines.add(lines);
      }

      // ─── Load component move lines ──────────────────────────────────────
      final moveLines = <dynamic>[];
      for (var move in moveProducts) {
        final lines = await odooMoService.loadProductsMoveLine(move.id);
        moveLines.add(lines);
      }

      // Combine both finished and component move lines
      emit(ProductMoveLoaded(moveLines: finishedMoveLines + moveLines));
    } catch (e) {
      emit(ProductMoveError(message: e.toString()));
    }
  }
}
