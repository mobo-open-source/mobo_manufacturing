import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/mo_work_order.dart';
import '../../models/stock_move.dart';
import '../../widgets/mo_overview_widgets.dart';
import 'mo_overview_event.dart';
import 'mo_overview_state.dart';

/// BLoC responsible for preparing and managing the UI components of the MO Overview page.
///
/// This bloc:
/// • Receives initial MO data (moItem, moveProducts, workOrders) via constructor
/// • Builds the header card and material table widgets asynchronously
/// • Emits loading → loaded (with built widgets) or error states
/// • Uses dark mode flag to pass theme information to widget builders
///
/// The actual widget building logic lives in `mo_overview_widgets.dart`
/// (functions: buildHeaderCard, buildMaterialTable).
class MOOverviewBloc extends Bloc<MOOverviewEvent, MOOverviewState> {
  final bool isDark;
  final List<dynamic> moItem;
  final List<StockMove> moveProducts;
  final List<MoWorkOrder> workOrders;

  MOOverviewBloc({
    required this.isDark,
    required this.moItem,
    required this.moveProducts,
    required this.workOrders,
  }) : super(MOOverviewLoading()) {
    on<LoadMOOverviewEvent>(_onLoadMOOverview);
  }

  /// Handles the initial data loading and UI component building event.
  ///
  /// Flow:
  /// 1. Emits loading state
  /// 2. Builds header card widget (summary info)
  /// 3. Builds material table widget (components list)
  /// 4. Emits loaded state containing both pre-built widgets
  /// 5. On any error → emits error state with message
  Future<void> _onLoadMOOverview(
    LoadMOOverviewEvent event,
    Emitter<MOOverviewState> emit,
  ) async {
    try {
      emit(MOOverviewLoading());

      // Build header summary card
      final headerCard = await buildHeaderCard(
        isDark,
        moItem,
        moveProducts,
        workOrders,
      );

      // Build components/materials table
      final materialTable = await buildMaterialTable(isDark,moveProducts, workOrders);

      emit(
        MOOverviewLoaded(headerCard: headerCard, materialTable: materialTable),
      );
    } catch (e) {
      emit(MOOverviewError(message: e.toString()));
    }
  }
}
