import 'package:flutter_bloc/flutter_bloc.dart';
import '../service/scrap_service.dart';
import '../model/scrap.dart';
import 'scrap_event.dart';
import 'scrap_state.dart';

/// BLoC responsible for managing the state of the Scrap list screen.
///
/// Handles:
/// - Loading paginated scrap items (stock.scrap) from Odoo
/// - Search, filtering (by status/product/date), and grouping
/// - Refresh, pagination, and group expand/collapse toggling
/// - Error handling and loading states
class ScrapBloc extends Bloc<ScrapEvent, ScrapState> {
  /// Fixed page size used for pagination
  static const int itemsPerPage = 40;

  ScrapBloc() : super(ScrapInitial()) {
    // Immediately show loading state on creation
    emit(ScrapLoading());

    on<LoadScrapItems>(_onLoadScrapItems);
    on<RefreshScrap>(_onRefreshScrap);
    on<ApplyScrapFiltersAndGroup>(_onApplyFiltersAndGroup);
    on<ClearScrapFilters>(_onClearFilters);
    on<ToggleGroupExpanded>(_onToggleGroupExpanded);
  }

  /// Groups scrap items by the selected criteria (product, location, scrap location, MO, etc.).
  ///
  /// Returns a list of maps in format:
  /// ```dart
  /// [{'group': 'Product XYZ', 'items': [item1, item2, ...]}, ...]
  /// ```
  /// Returns empty list if no grouping is applied.
  List<Map<String, dynamic>> _groupScrapItems(
    List<ScrapItem> items,
    String? groupBy,
  ) {
    if (groupBy == null || groupBy.isEmpty) return [];

    final Map<String, List<ScrapItem>> groups = {};

    for (final item in items) {
      String key;

      switch (groupBy) {
        case 'product':
          key = item.product ?? 'Unknown Product';
          break;
        case 'location':
          key = item.location ?? 'No Location';
          break;
        case 'scrap':
          key = item.scrapLocation ?? 'No Scrap Location';
          break;
        case 'mo':
          key = item.manufacturingOrder ?? 'No MO';
          break;
        default:
          key = 'Other';
      }

      groups.putIfAbsent(key, () => []).add(item);
    }

    return groups.entries.map((entry) {
      return {'group': entry.key, 'items': entry.value};
    }).toList();
  }

  /// Toggles the expanded/collapsed state of a specific group in grouped view.
  ///
  /// Only updates the `groupExpanded` map — does not trigger new data fetch.
  Future<void> _onToggleGroupExpanded(
    ToggleGroupExpanded event,
    Emitter<ScrapState> emit,
  ) async {
    if (state is ScrapLoaded) {
      final current = state as ScrapLoaded;
      final newExpanded = Map<String, bool>.from(current.groupExpanded);
      newExpanded[event.groupKey] = !(newExpanded[event.groupKey] ?? true);

      emit(current.copyWith(groupExpanded: newExpanded));
    }
  }

  /// Main handler for loading scrap items with pagination, search, filters, and grouping.
  ///
  /// - Fetches data via `ScrapService`
  /// - Applies client-side grouping if requested
  /// - Emits `ScrapLoaded` on success or error state on failure
  Future<void> _onLoadScrapItems(
    LoadScrapItems event,
    Emitter<ScrapState> emit,
  ) async {
    try {
      final scrapService = ScrapService();
      await scrapService.initializeClient();
      final (items, total) = await scrapService.loadScrap(
        page: event.page,
        search: event.search,
        productId: event.productId,
        date: event.date,
        filter: event.statusFilters,
        group: event.groupBy,
      );
      final grouped = _groupScrapItems(items, event.groupBy);
      emit(
        ScrapLoaded(
          items: items,
          groupedItems: grouped,
          totalCount: total,
          currentPage: event.page,
          search: event.search,
          productId: event.productId,
          date: event.date,
          statusFilters: event.statusFilters ?? [],
          groupBy: event.groupBy,
          groupExpanded: {},
        ),
      );
    } catch (e) {
      emit(
        ScrapLoaded(
          items: [],
          groupedItems: [],
          currentPage: event.page,
          totalCount: 0,
          catchError: true,
        ),
      );
    }
  }

  /// Refreshes the current page with existing filters/search/grouping.
  ///
  /// Useful for pull-to-refresh or after mutations (e.g. delete scrap).
  Future<void> _onRefreshScrap(
    RefreshScrap event,
    Emitter<ScrapState> emit,
  ) async {
    if (state is ScrapLoaded) {
      final current = state as ScrapLoaded;
      add(
        LoadScrapItems(
          page: current.currentPage,
          search: current.search,
          productId: current.productId,
          date: current.date,
          statusFilters: current.statusFilters,
          groupBy: current.groupBy,
        ),
      );
    } else {
      add(const LoadScrapItems(page: 0));
    }
  }

  /// Applies new filters/grouping and resets pagination to page 0.
  ///
  /// Triggers a full reload with the new criteria.
  Future<void> _onApplyFiltersAndGroup(
    ApplyScrapFiltersAndGroup event,
    Emitter<ScrapState> emit,
  ) async {
    emit(ScrapLoading());

    add(
      LoadScrapItems(
        page: 0,
        search: (state is ScrapLoaded) ? (state as ScrapLoaded).search : null,
        productId: (state is ScrapLoaded)
            ? (state as ScrapLoaded).productId
            : null,
        date: (state is ScrapLoaded) ? (state as ScrapLoaded).date : null,
        statusFilters: event.statusFilters,
        groupBy: event.groupBy,
      ),
    );
  }

  /// Clears all filters and grouping, then reloads from page 0.
  Future<void> _onClearFilters(
    ClearScrapFilters event,
    Emitter<ScrapState> emit,
  ) async {
    emit(ScrapLoading());
    add(const LoadScrapItems(page: 0));
  }
}
