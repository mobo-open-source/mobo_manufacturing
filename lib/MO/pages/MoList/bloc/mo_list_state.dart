import 'package:equatable/equatable.dart';

/// Base class for all states in the Manufacturing Orders (MO) list feature.
/// Uses Equatable to enable efficient state comparison in BLoC.
abstract class MOListState extends Equatable {
  const MOListState();

  @override
  List<Object?> get props => [];
}

/// Initial / empty state before any data has been requested
class MOListInitial extends MOListState {}

/// Loading state — shown when fetching data (especially on full refresh)
class MOListLoading extends MOListState {}

/// Success state containing loaded manufacturing orders and UI-related metadata
class MOListLoaded extends MOListState {
  final List<Map<String, dynamic>> moItems;
  final String userTz;

  final int currentPage;
  final int itemsPerPage;
  final int totalCount;
  final List<String> selectedFilters;
  final String? selectedGroupBy;
  final String? selectedStartDateUnit;
  final List<Map<String, dynamic>>
  groupedMos;
  final Map<String, bool> groupExpanded;

  const MOListLoaded({
    required this.moItems,
    required this.userTz,
    this.currentPage = 0,
    this.itemsPerPage = 40,
    this.totalCount = 0,
    this.selectedFilters = const [],
    this.selectedGroupBy,
    this.selectedStartDateUnit,
    this.groupedMos = const [],
    this.groupExpanded = const {},
  });

  /// Creates a new instance with grouping applied based on `selectedGroupBy`
  ///
  /// Groups `moItems` by the selected criteria (product, status, procurement group).
  /// Preserves previous expansion state where possible, defaults new groups to expanded.
  MOListLoaded withGroupedData() {
    if (selectedGroupBy == null || selectedGroupBy!.isEmpty) {
      return copyWith(groupedMos: [], groupExpanded: {});
    }

    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (var mo in moItems) {
      String groupKey;

      if (selectedGroupBy == "product") {
        groupKey = mo['product_id']?[1] as String? ?? 'Unknown Product';
      } else if (selectedGroupBy == "status") {
        groupKey = mo['state'] as String? ?? 'Unknown';
      } else if (selectedGroupBy == "group") {
        groupKey = mo['procurement_group_id']?[1] as String? ?? 'No Group';
      } else {
        groupKey = 'Ungrouped';
      }

      groups.putIfAbsent(groupKey, () => []).add(mo);
    }

    final List<Map<String, dynamic>> newGrouped = groups.entries.map((e) {
      return {"group": e.key, "mos": e.value};
    }).toList();

    final Map<String, bool> newExpanded = {
      ...groupExpanded,
      for (var group in newGrouped)
        group["group"] as String:
            groupExpanded[group["group"] as String] ?? true,
    };

    return copyWith(groupedMos: newGrouped, groupExpanded: newExpanded);
  }

  /// Human-readable string showing current page range (used in pagination UI)
  /// Example: "1-40", "41-80", or "141-152" if fewer items on last page
  String get pageRange {
    final start = currentPage * itemsPerPage + 1;
    final end = (currentPage + 1) * itemsPerPage;
    return '$start-${end > totalCount ? totalCount : end}';
  }

  @override
  List<Object?> get props => [
    moItems,
    userTz,
    currentPage,
    itemsPerPage,
    totalCount,
    selectedFilters,
    selectedGroupBy,
    selectedStartDateUnit,
    groupedMos,
    groupExpanded,
  ];

  /// Creates a modified copy of this state with some fields overridden
  MOListLoaded copyWith({
    List<Map<String, dynamic>>? moItems,
    String? userTz,
    int? currentPage,
    int? itemsPerPage,
    int? totalCount,
    List<String>? selectedFilters,
    String? selectedGroupBy,
    String? selectedStartDateUnit,
    List<Map<String, dynamic>>? groupedMos,
    Map<String, bool>? groupExpanded,
  }) {
    return MOListLoaded(
      moItems: moItems ?? this.moItems,
      userTz: userTz ?? this.userTz,
      currentPage: currentPage ?? this.currentPage,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      totalCount: totalCount ?? this.totalCount,
      selectedFilters: selectedFilters ?? this.selectedFilters,
      selectedGroupBy: selectedGroupBy ?? this.selectedGroupBy,
      selectedStartDateUnit:
          selectedStartDateUnit ?? this.selectedStartDateUnit,
      groupedMos: groupedMos ?? this.groupedMos,
      groupExpanded: groupExpanded ?? this.groupExpanded,
    );
  }
}

/// Error state — shown when data fetching fails
class MOListError extends MOListState {
  final String? message;
  final bool catchError;

  const MOListError({
    this.message,
    this.catchError = true,
  });

  @override
  List<Object?> get props => [message,catchError];
}
