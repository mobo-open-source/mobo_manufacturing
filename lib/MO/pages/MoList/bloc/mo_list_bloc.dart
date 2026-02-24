import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/manufacturing_order_service.dart';
import 'mo_list_event.dart';
import 'mo_list_state.dart';

/// Central BLoC managing the Manufacturing Orders list screen.
/// Handles data fetching, pagination, filtering, grouping, and UI interactions
/// like expanding/collapsing grouped sections.
class MOListBloc extends Bloc<MOListEvent, MOListState> {
  final ManufacturingOrderService _service;

  MOListBloc(this._service) : super(MOListInitial()) {
    on<FetchMOList>(_onFetchMOList);
    on<ClearFilters>(_onClearFilters);
    on<ApplyFiltersAndGroupBy>(_onApplyFiltersAndGroupBy);
    on<ToggleGroupExpanded>(_onToggleGroupExpanded);
  }

  /// Called when user taps to expand or collapse a grouped section in grouped view.
  /// Updates only the expanded state map without triggering new data fetch.
  Future<void> _onToggleGroupExpanded(
    ToggleGroupExpanded event,
    Emitter<MOListState> emit,
  ) async {
    if (state is MOListLoaded) {
      final current = state as MOListLoaded;
      final newExpanded = Map<String, bool>.from(current.groupExpanded);
      newExpanded[event.groupName] =
          !(current.groupExpanded[event.groupName] ?? true);
      emit(current.copyWith(groupExpanded: newExpanded));
    }
  }

  /// Triggered when user taps "Clear All" in filter sheet or reset button.
  /// Resets all filter/group selections to default and reloads fresh data from page 0.
  Future<void> _onClearFilters(
    ClearFilters event,
    Emitter<MOListState> emit,
  ) async {
    if (state is MOListLoaded) {
      final current = state as MOListLoaded;
      emit(
        current.copyWith(
          selectedFilters: const [],
          selectedGroupBy: null,
          selectedStartDateUnit: null,
        ),
      );
    }
    add(const FetchMOList(page: 0));
  }

  /// Fired when user applies new filters or changes grouping from the bottom sheet.
  /// Updates preserved filter/group state first, then triggers data reload from page 1.
  Future<void> _onApplyFiltersAndGroupBy(
    ApplyFiltersAndGroupBy event,
    Emitter<MOListState> emit,
  ) async {
    if (state is MOListLoaded) {
      var current = state as MOListLoaded;
      current = current.copyWith(
        selectedFilters: event.filters,
        selectedGroupBy: event.groupBy,
        selectedStartDateUnit: event.startDateUnit,
      );

      if (event.groupBy != null && event.groupBy!.isNotEmpty) {
        current = current.withGroupedData();
      }

      emit(current);
    }
    add(FetchMOList(page: 0, filters: event.filters, groupBy: event.groupBy));
  }

  /// Core data loading handler.
  /// Responsible for:
  ///   - Showing loading state on full refresh (page 0)
  ///   - Resolving user timezone
  ///   - Fetching total count + paginated items from Odoo backend
  ///   - Preserving current filters when paginating
  ///   - Applying grouping if active
  Future<void> _onFetchMOList(
    FetchMOList event,
    Emitter<MOListState> emit,
  ) async {
    try {
      if (event.page == 0) emit(MOListLoading());

      String tz =
          event.userTz ??
          (await SharedPreferences.getInstance()).getString('userTimezone') ??
          'UTC';

      await _service.initializeClient();

      // Use event filters if provided, otherwise keep previously selected ones
      List<String> activeFilters = event.filters ?? [];
      if (activeFilters.isEmpty && state is MOListLoaded) {
        activeFilters = (state as MOListLoaded).selectedFilters;
      }

      // Fetch metadata (total count) and actual paginated records
      final totalCount = await _service.fetchManufacturingOrdersCount(
        event.page,
        event.itemsPerPage,
        searchTerm: event.searchTerm,
        selectedFilters: activeFilters,
      );

      final results = await _service.fetchManufacturingOrders(
        event.page,
        event.itemsPerPage,
        searchTerm: event.searchTerm,
        selectedFilters: activeFilters,
      );
      final typedItems = results.whereType<Map<String, dynamic>>().toList();

      // Construct new loaded state while preserving filter/group selections
      var newState = MOListLoaded(
        moItems: typedItems,
        userTz: tz,
        currentPage: event.page,
        itemsPerPage: event.itemsPerPage,
        totalCount: totalCount,
        selectedFilters: activeFilters,
        selectedGroupBy:
            event.groupBy ??
            (state is MOListLoaded
                ? (state as MOListLoaded).selectedGroupBy
                : null),
      );

      // Apply grouping transformation if grouping is active
      if (newState.selectedGroupBy != null &&
          newState.selectedGroupBy!.isNotEmpty) {
        newState = newState.withGroupedData();
      }

      emit(newState);
    } catch (e) {
      emit(
        const MOListError(
          message: 'Failed to load manufacturing orders',
          catchError: true,
        ),
      );
    }
  }
}
