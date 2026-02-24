import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../globals.dart';
import 'package:hugeicons/hugeicons.dart';
import '../pages/MoList/bloc/mo_list_bloc.dart';
import '../pages/MoList/bloc/mo_list_event.dart';
import '../pages/MoList/bloc/mo_list_state.dart';
import '../pages/MoList/pages/mo_list.dart';

/// Top search bar for Manufacturing Orders list screen.
///
/// Features:
/// - Text field for free-text search (name, state, product, BOM)
/// - Filter icon button that opens the advanced filter & group-by bottom sheet
/// - Live search: triggers `FetchMOList` event on every text change (debouncing not included)
///
/// Maintains current filters & grouping when searching.
class SearchFilterBar extends StatefulWidget {
  final TextEditingController searchController;
  final DateTime? selectedScheduleDate;
  final DateTime? selectedEndDate;
  final bool isFilterApplied;
  final Function(DateTime?, DateTime?, bool, String) onFilterApplied;
  final VoidCallback onClearFilter;
  final String selectedView;

  const SearchFilterBar({
    super.key,
    required this.searchController,
    required this.selectedScheduleDate,
    required this.selectedEndDate,
    required this.isFilterApplied,
    required this.onFilterApplied,
    required this.onClearFilter,
    required this.selectedView,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              // Card-like shadow and rounded background
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF000000).withOpacity(0.05),
                    offset: const Offset(0, 6),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xffF8FAFB),
                border: Border.all(color: Colors.transparent, width: 1),
              ),
              child: TextField(
                controller: widget.searchController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  hintText: 'Search Manufacturing Orders...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white : Color(0xff1E1E1E),
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                  ),
                  // Filter icon button (opens advanced filter sheet)
                  prefixIcon: IconButton(
                    icon: Icon(
                      HugeIcons.strokeRoundedFilterHorizontal,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      size: 18,
                    ),
                    tooltip: 'Filter & Group By',
                    onPressed: () {
                      context.findAncestorStateOfType<MOListViewState>()?.openFilterGroupBySheet(context);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppStyle.primaryColor),
                  ),
                ),
                // Live search: dispatch FetchMOList event with current filters & grouping
                onChanged: (value) async {
                  final bloc = context.read<MOListBloc>();
                  final currentState = bloc.state;

                  final List<String> currentFilters = currentState is MOListLoaded
                      ? currentState.selectedFilters
                      : const [];

                  final String? currentGroupBy = currentState is MOListLoaded
                      ? currentState.selectedGroupBy
                      : null;
                  context.read<MOListBloc>().add(
                    FetchMOList(
                      searchTerm: value,
                      filters: currentFilters,
                      groupBy: currentGroupBy,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
