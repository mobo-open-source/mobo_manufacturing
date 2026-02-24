import 'package:equatable/equatable.dart';

/// Base class for all events in the Scrap list/feature BLoC.
///
/// All events extend this class to ensure proper equality comparison
/// (via Equatable) and consistent handling in the ScrapBloc.
abstract class ScrapEvent extends Equatable {
  const ScrapEvent();

  @override
  List<Object?> get props => [];
}

/// Primary event to load or reload scrap items (stock.scrap records).
///
/// Supports:
/// - Pagination (page number)
/// - Free-text search
/// - Filtering by product and/or date
/// - Status filters (e.g. draft, done)
/// - Grouping (client-side after fetch)
class LoadScrapItems extends ScrapEvent {
  final int page;
  final String? search;
  final int? productId;
  final DateTime? date;
  final List<String>? statusFilters;
  final String? groupBy;

  const LoadScrapItems({
    required this.page,
    this.search,
    this.productId,
    this.date,
    this.statusFilters,
    this.groupBy,
  });

  @override
  List<Object?> get props => [
    page,
    search,
    productId,
    date,
    statusFilters,
    groupBy,
  ];
}

/// Event to refresh the current page with existing filters/search/grouping.
///
/// Usually triggered by pull-to-refresh or after data mutations.
class RefreshScrap extends ScrapEvent {
  const RefreshScrap();
}

/// Event fired when user applies new status filters and/or grouping from the bottom sheet.
///
/// Resets pagination to page 0 and triggers a full reload.
class ApplyScrapFiltersAndGroup extends ScrapEvent {
  final List<String> statusFilters;
  final String? groupBy;

  const ApplyScrapFiltersAndGroup({
    required this.statusFilters,
    this.groupBy,
  });

  @override
  List<Object?> get props => [statusFilters, groupBy];
}

/// Event to clear all filters and grouping, then reload from page 0.
class ClearScrapFilters extends ScrapEvent {
  const ClearScrapFilters();
}

/// Event to toggle the expanded/collapsed state of a specific group
/// in the grouped list view (e.g. expand all items under "Product X").
///
/// Only updates UI expansion state — does not reload data.
class ToggleGroupExpanded extends ScrapEvent {
  /// The group identifier/key to toggle (e.g. product, location)
  final String groupKey;

  const ToggleGroupExpanded(this.groupKey);

  @override
  List<Object?> get props => [groupKey];
}