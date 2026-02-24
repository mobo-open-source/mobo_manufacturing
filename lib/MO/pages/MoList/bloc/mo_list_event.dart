import 'package:equatable/equatable.dart';

/// Base class for all events in the Manufacturing Orders (MO) list feature.
/// All events must extend this class to ensure proper equality comparison.
abstract class MOListEvent extends Equatable {
  const MOListEvent();

  @override
  List<Object?> get props => [];
}

/// Primary event to fetch or refresh the list of Manufacturing Orders.
///
/// Supports:
/// - Pagination (page & itemsPerPage)
/// - Search by term
/// - Filtering by status/technical state
/// - Grouping (product, status, procurement group)
/// - View mode awareness (though mainly handled in UI)
class FetchMOList extends MOListEvent {
  final int page;
  final int itemsPerPage;
  final String searchTerm;
  final String? userTz;
  final String selectedView;
  final List<String>? filters;
  final String? groupBy;

  const FetchMOList({
    this.page = 0,
    this.itemsPerPage = 40,
    this.searchTerm = '',
    this.userTz,
    this.selectedView = "list",
    this.filters,
    this.groupBy,
  });

  @override
  List<Object?> get props => [
    page,
    itemsPerPage,
    searchTerm,
    userTz,filters,groupBy
  ];
}

/// Event triggered when user wants to reset all filters and grouping settings.
///
/// Usually fired from "Clear All" button in filter bottom sheet.
/// Resets state and triggers fresh fetch from page 0.
class ClearFilters extends MOListEvent {
  const ClearFilters();
}

/// Event fired when user applies new filter selection and/or grouping from
/// the filter & group-by bottom sheet.
///
/// Carries the new filter list and grouping choice to be persisted
/// and used in subsequent data fetches.
class ApplyFiltersAndGroupBy extends MOListEvent {
  final List<String> filters;
  final String? groupBy;
  final String? startDateUnit;

  const ApplyFiltersAndGroupBy({
    required this.filters,
    this.groupBy,
    this.startDateUnit,
  });
}

/// Event dispatched when user taps to expand or collapse a specific group
/// in the grouped list view (e.g. all MOs for "Product X" or "In Progress").
///
/// Only updates UI expansion state — does not trigger data reload.
class ToggleGroupExpanded extends MOListEvent {
  final String groupName;
  const ToggleGroupExpanded(this.groupName);
}