import 'package:equatable/equatable.dart';
import '../model/scrap.dart';

/// Base class for all states in the Scrap list/feature BLoC.
///
/// Uses Equatable to enable efficient state comparison and rebuild prevention
/// in the UI when only relevant parts of the state change.
abstract class ScrapState extends Equatable {
  const ScrapState();

  @override
  List<Object?> get props => [];
}

/// Initial empty state before any data has been requested
class ScrapInitial extends ScrapState {}

/// Loading state — shown during initial fetch or refresh
class ScrapLoading extends ScrapState {}

/// Success state containing loaded scrap items and all UI-related metadata
class ScrapLoaded extends ScrapState {
  /// List of raw scrap items fetched from backend
  final List<ScrapItem> items;

  /// Pre-grouped data when grouping is active
  /// Format: [{'group': 'Product XYZ', 'items': [item1, item2, ...]}, ...]
  final List<Map<String, dynamic>> groupedItems;

  final int totalCount;
  final int currentPage;
  final String? search;
  final int? productId;
  final DateTime? date;
  final bool catchError;
  final List<String> statusFilters;
  final String? groupBy;
  final Map<String, bool> groupExpanded;

  const ScrapLoaded({
    required this.items,
    this.groupedItems = const [],
    required this.totalCount,
    required this.currentPage,
    this.search,
    this.productId,
    this.date,
    this.catchError = false,
    this.statusFilters = const [],
    this.groupBy,
    this.groupExpanded = const {},
  });

  /// Computed property: whether grouping is currently active
  bool get isGrouped => groupBy != null && groupBy!.isNotEmpty;

  /// Creates a modified copy of this state with some fields overridden
  ///
  /// Very useful for immutable state updates (e.g. toggling group expansion,
  /// applying new filters without full reload)
  ScrapLoaded copyWith({
    List<ScrapItem>? items,
    List<Map<String, dynamic>>? groupedItems,
    int? totalCount,
    int? currentPage,
    String? search,
    int? productId,
    DateTime? date,
    bool? catchError,
    List<String>? statusFilters,
    String? groupBy,
    Map<String, bool>? groupExpanded,
  }) {
    return ScrapLoaded(
      items: items ?? this.items,
      groupedItems: groupedItems ?? this.groupedItems,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      search: search ?? this.search,
      productId: productId ?? this.productId,
      date: date ?? this.date,
      catchError: catchError ?? this.catchError,
      statusFilters: statusFilters ?? this.statusFilters,
      groupBy: groupBy ?? this.groupBy,
      groupExpanded: groupExpanded ?? this.groupExpanded,
    );
  }

  @override
  List<Object?> get props => [
    items,
    groupedItems,
    totalCount,
    currentPage,
    search,
    productId,
    date,
    catchError,
    statusFilters,
    groupBy,
    groupExpanded,
  ];
}

/// Error state — shown when data fetching fails
class ScrapError extends ScrapState {
  final String message;
  final ScrapLoaded? previousState;

  const ScrapError({
    required this.message,
    this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];
}