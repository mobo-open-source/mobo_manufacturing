import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_manufacturing_app/Scrap/pages/scrap_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../Dashboard/infrastructure/profile_refresh_bus.dart';
import '../../core/company/infrastructure/company_refresh_bus.dart';
import '../../core/company/providers/company_provider.dart';
import '../../core/providers/motion_provider.dart';
import '../../globals.dart';
import '../bloc/scrap_bloc.dart';
import '../bloc/scrap_event.dart';
import '../bloc/scrap_state.dart';
import '../model/scrap.dart';
import '../service/scrap_service.dart';

/// Main page displaying the list of Scrap items (stock.scrap records).
///
/// Features:
/// - Paginated list with pull-to-refresh
/// - Search bar with live/debounced filtering
/// - Advanced filter & group-by bottom sheet
/// - Grouped view support (by product, location, etc.)
/// - Pagination controls with page range display
/// - Empty/error states with Lottie animations
/// - Navigation to scrap detail page on card tap
class ScrapListPage extends StatefulWidget {
  const ScrapListPage({super.key});

  @override
  State<ScrapListPage> createState() => _ScrapListPageState();
}

class _ScrapListPageState extends State<ScrapListPage> {
  int _currentPage = 0;
  bool _isPaginationLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  bool isFilterApplied = false;
  Timer? _debounce;

  // Product dropdown data
  List<Map<String, dynamic>> productItem = [];
  int? selectedProductId;
  Map<String, dynamic>? selectedProduct;

  // Date & product filters
  DateTime? _filterDate;
  int? _filterProductId;

  // UI filter/group badges state
  bool hasFilters = false;
  bool hasGroupBy = false;

  // Filter options (technical names for Odoo domain)
  final Map<String, String> filterTechnicalNames = {
    "Done": "done",
    "Draft": "draft",
  };

  // Grouping options
  final Map<String, String> groupTechnicalNames = {
    "Product": "product",
    "Location": "location",
    "Scrap Location": "scrap",
    "Transfer": "transfer",
    "Manufacturing Order": "mo",
  };

  @override
  void initState() {
    super.initState();
    _loadProducts();

    // Live search with debounce
    _searchController.addListener(() {
      final text = _searchController.text;
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () {
        _searchText = text;
        _applyFilters(page: 0);
      });
    });
  }

  /// Applies current search + filter + page settings by dispatching LoadScrapItems event
  void _applyFilters({required int page}) {
    setState(() {
      _isPaginationLoading = true;
    });
    context.read<ScrapBloc>().add(
      LoadScrapItems(
        page: page,
        search: _searchText.isEmpty ? null : _searchText,
        productId: _filterProductId,
        date: _filterDate,
      ),
    );
  }

  /// Loads all available products from Odoo for filter dropdown
  Future<void> _loadProducts() async {
    final odooScrapService = ScrapService();
    await odooScrapService.initializeClient();
    final productResponse = await odooScrapService.loadProduct();
    setState(() {
      productItem = productResponse ?? [];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Loads a specific page of scrap items
  void _loadPage(int page) {
    setState(() {
      _currentPage = page;
      _isPaginationLoading = true;
    });
    _applyFilters(page: page);
  }

  /// Generates human-readable page range string (e.g. "1-40 / 145")
  String _pageRange(ScrapLoaded state) {
    final start = state.currentPage * ScrapBloc.itemsPerPage + 1;
    final end = (state.currentPage + 1) * ScrapBloc.itemsPerPage;
    return '$start-${end > state.totalCount ? state.totalCount : end}';
  }

  /// Opens the advanced filter & group-by bottom sheet
  void openFilterGroupBySheet(BuildContext context) {
    final bloc = context.read<ScrapBloc>();
    final currentState = bloc.state;

    List<String> tempFilters = [];
    String? tempGroupBy;

    if (currentState is ScrapLoaded) {
      tempFilters = List.from(currentState.statusFilters);
      tempGroupBy = currentState.groupBy;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final groupMap = groupTechnicalNames;

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF232323) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter & Group By',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: isDark ? Colors.white : Colors.black54,
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // Tab bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        color: isDark
                            ? Color(0xFF2A2A2A)
                            : AppStyle.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Color(0xFF2A2A2A).withOpacity(0.3)
                                : AppStyle.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorPadding: const EdgeInsets.all(4),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      tabs: [
                        Tab(height: 48, text: "Filter"),
                        Tab(height: 48, text: "Group By"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filterTechnicalNames.keys.map((label) {
                              final tech = filterTechnicalNames[label]!;
                              final selected = tempFilters.contains(tech);

                              return FilterChip(
                                label: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: selected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white70
                                              : Colors.black87),
                                  ),
                                ),
                                selected: selected,
                                selectedColor: isDark
                                    ? Color(0xFF131313)
                                    : AppStyle.primaryColor,
                                backgroundColor: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                checkmarkColor: Colors.white,
                                onSelected: (val) {
                                  setDialogState(() {
                                    if (val) {
                                      tempFilters.add(tech);
                                    } else {
                                      tempFilters.remove(tech);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),

                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: groupMap.keys.map((label) {
                            final tech = groupMap[label]!;
                            final isSelected = tempGroupBy == tech;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      tempGroupBy = tech;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    margin: const EdgeInsets.only(
                                      bottom: 6,
                                      left: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_unchecked,
                                          color: isSelected
                                              ? (isDark
                                                    ? Colors.white
                                                    : AppStyle.primaryColor)
                                              : Colors.grey,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          label,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons (Clear All + Apply)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[50],
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              bloc.add(
                                ClearScrapFilters(),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white
                                  : Colors.black87,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey[600]!
                                    : Colors.grey[300]!,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Clear All',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              bloc.add(
                                ApplyScrapFiltersAndGroup(
                                  statusFilters: tempFilters,
                                  groupBy: tempGroupBy,
                                ),
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Apply',
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds a centered placeholder with Lottie animation, title, subtitle, and optional action button
  /// Used for empty states and error states
  Widget _buildCenteredLottie({
    required String lottie,
    required String title,
    String? subtitle,
    Widget? button,
    required bool isDark,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(lottie, width: 260),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                  if (button != null) ...[const SizedBox(height: 12), button],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocConsumer<ScrapBloc, ScrapState>(
      listener: (context, state) {
        if (state is ScrapLoaded) {
          setState(() => _isPaginationLoading = false);
        }
      },
      builder: (context, state) {
        // Loading state (initial or pagination)
        if (state is ScrapLoading || _isPaginationLoading) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                child: Container(
                  width: double.infinity,
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
                    controller: _searchController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      hintText: 'Search Scrap Items...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white : const Color(0xff1E1E1E),
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                      prefixIcon: IconButton(
                        icon: Icon(
                          HugeIcons.strokeRoundedFilterHorizontal,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          size: 18,
                        ),
                        tooltip: 'Filter by status',
                        onPressed: () => openFilterGroupBySheet(context),
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
                  ),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: 5,
                  itemBuilder: (_, __) => _buildShimmer(context),
                ),
              ),
            ],
          );
        }

        // Error state
        if (state is ScrapLoaded && state.catchError) {
          return Center(
            child: _buildCenteredLottie(
              lottie: 'assets/Error_404.json',
              title: 'Something went wrong',
              subtitle: 'Tap Retry to refresh',
              isDark: isDark,
              button: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? Colors.white
                      : AppStyle.primaryColor,
                  side: BorderSide(
                    color: isDark
                        ? Colors.grey[600]!
                        : AppStyle.primaryColor.withOpacity(0.3),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await context.read<CompanyProvider>().initialize();
                  ProfileRefreshBus.notifyProfileRefresh();
                  CompanyRefreshBus.notify();
                },
                child: Text(
                  'Retry',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }
        if (state is ScrapLoaded && state.items.isEmpty) {
          hasFilters = state.statusFilters.isNotEmpty;
          hasGroupBy = (state.groupBy?.isNotEmpty ?? false);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                child: Container(
                  width: double.infinity,
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
                    controller: _searchController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      hintText: 'Search Scrap Items...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white : const Color(0xff1E1E1E),
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                      prefixIcon: IconButton(
                        icon: Icon(
                          HugeIcons.strokeRoundedFilterHorizontal,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          size: 18,
                        ),
                        tooltip: 'Filter by status',
                        onPressed: () => openFilterGroupBySheet(context),
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
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 35,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) {
                            hasFilters = state.statusFilters.isNotEmpty;
                            hasGroupBy = (state.groupBy?.isNotEmpty ?? false);

                            if (!hasFilters && !hasGroupBy) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Text(
                                  "No filters applied",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }

                            String? groupDisplayName;
                            if (hasGroupBy) {
                              final groupMap = {
                                "Product": "product",
                                "Status": "status",
                                "Procurement Group": "group",
                              };

                              groupDisplayName = groupMap.keys.firstWhere(
                                (key) => groupMap[key] == state.statusFilters,
                                orElse: () =>
                                    state.groupBy!.replaceAll('_', ' '),
                              );
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasFilters)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          state.statusFilters.length.toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Active",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (hasGroupBy) ...[
                                  if (hasFilters) const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedLayer,
                                          size: 16,
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          groupDisplayName ?? "Group",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _pageRange(state),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '/',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${state.totalCount}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: InkWell(
                                onTap: _currentPage > 0
                                    ? () => _loadPage(_currentPage - 1)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    HugeIcons.strokeRoundedArrowLeft01,
                                    size: 20,
                                    color: state.currentPage > 0
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.grey[600]
                                              : Colors.grey[400]),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: InkWell(
                                onTap:
                                    (_currentPage + 1) *
                                            ScrapBloc.itemsPerPage <
                                        state.totalCount
                                    ? () => _loadPage(_currentPage + 1)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    HugeIcons.strokeRoundedArrowRight01,
                                    size: 20,
                                    color:
                                        (_currentPage + 1) *
                                                ScrapBloc.itemsPerPage <
                                            state.totalCount
                                        ? (isDark
                                              ? Colors.white70
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.grey[800]
                                              : Colors.grey.withOpacity(0.7)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _loadPage(0),
                  child: _buildCenteredLottie(
                    lottie: 'assets/empty_ghost.json',
                    title: 'No scrap items found',
                    subtitle: hasFilters ? 'Try adjusting your filter' : null,
                    isDark: isDark,
                    button: hasFilters
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey[600]!
                                    : AppStyle.primaryColor.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () {
                              context.read<ScrapBloc>().add(ClearScrapFilters());
                            },
                            child: Text(
                              'Clear All Filters',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppStyle.primaryColor,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          );
        }

        // Loaded state with data
        if (state is ScrapLoaded) {
          final items = state.items;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                child: Container(
                  width: double.infinity,
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
                    controller: _searchController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      hintText: 'Search Scrap Items...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white : const Color(0xff1E1E1E),
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                      prefixIcon: IconButton(
                        icon: Icon(
                          HugeIcons.strokeRoundedFilterHorizontal,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          size: 18,
                        ),
                        tooltip: 'Filter by status',
                        onPressed: () => openFilterGroupBySheet(context),
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
                  ),
                ),
              ),

              // Pagination & badges
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width - 35,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Builder(
                          builder: (context) {
                            hasFilters = state.statusFilters.isNotEmpty;
                            hasGroupBy = (state.groupBy?.isNotEmpty ?? false);

                            if (!hasFilters && !hasGroupBy) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Text(
                                  "No filters applied",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }

                            String? groupDisplayName;
                            if (hasGroupBy) {
                              final groupMap = {
                                "Product": "product",
                                "Status": "status",
                                "Procurement Group": "group",
                              };

                              groupDisplayName = groupMap.keys.firstWhere(
                                (key) => groupMap[key] == state.statusFilters,
                                orElse: () =>
                                    state.groupBy!.replaceAll('_', ' '),
                              );
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasFilters)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          state.statusFilters.length.toString(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "Active",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (hasGroupBy) ...[
                                  if (hasFilters) const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedLayer,
                                          size: 16,
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          groupDisplayName ?? "Group",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _pageRange(state),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '/',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${state.totalCount}',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: InkWell(
                                onTap: _currentPage > 0
                                    ? () => _loadPage(_currentPage - 1)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    HugeIcons.strokeRoundedArrowLeft01,
                                    size: 20,
                                    color: state.currentPage > 0
                                        ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.grey[600]
                                              : Colors.grey[400]),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: InkWell(
                                onTap:
                                    (_currentPage + 1) *
                                            ScrapBloc.itemsPerPage <
                                        state.totalCount
                                    ? () => _loadPage(_currentPage + 1)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    HugeIcons.strokeRoundedArrowRight01,
                                    size: 20,
                                    color:
                                        (_currentPage + 1) *
                                                ScrapBloc.itemsPerPage <
                                            state.totalCount
                                        ? (isDark
                                              ? Colors.white70
                                              : Colors.black87)
                                        : (isDark
                                              ? Colors.grey[800]
                                              : Colors.grey.withOpacity(0.7)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child:
                    state is ScrapLoaded &&
                        state.isGrouped &&
                        state.groupedItems.isNotEmpty
                    ? _buildGroupedList(state, isDark)
                    : RefreshIndicator(
                        onRefresh: () async => _loadPage(0),
                        child: ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (c, i) => _buildScrapCard(
                            c,
                            items[i],
                            () async => _loadPage(_currentPage),
                          ),
                        ),
                      ),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }

  /// Builds grouped list view when grouping is active
  Widget _buildGroupedList(ScrapLoaded state, bool isDark) {
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<ScrapBloc>().add(const RefreshScrap()),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: state.groupedItems.length,
        itemBuilder: (context, index) {
          final group = state.groupedItems[index];
          final groupName =
              (group['group'] as String?)?.trim().isNotEmpty == true
              ? group['group']
              : 'None';
          final groupItems = group['items'] as List<ScrapItem>;
          final isExpanded = state.groupExpanded[groupName] ?? true;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                    color: Colors.black.withOpacity(0.08),
                  ),
              ],
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    context.read<ScrapBloc>().add(
                      ToggleGroupExpanded(groupName),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                groupName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${groupItems.length} item${groupItems.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  ...groupItems.map(
                    (item) => _buildScrapCard(
                      context,
                      item,
                      () async =>
                          context.read<ScrapBloc>().add(const RefreshScrap()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Builds shimmer placeholder for a single scrap list item during loading
  Widget _buildShimmer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Container(height: 16, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Container(height: 16, width: 60, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Icon(Icons.category, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Container(height: 14, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Container(height: 14, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),

              Row(
                children: [
                  const Icon(
                    Icons.confirmation_num,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Container(height: 14, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a tappable card for a single Scrap item
  Widget _buildScrapCard(
    BuildContext context,
    ScrapItem scrap,
    Future<void> Function() refreshScrap,
  ) {
    String statusText;
    Color statusColor;

    switch (scrap.status.toLowerCase()) {
      case 'draft':
        statusText = 'Draft';
        statusColor = Colors.blue;
        break;
      case 'done':
        statusText = 'Done';
        statusColor = Colors.green;
        break;
      default:
        statusText = scrap.status.toUpperCase();
        statusColor = Colors.grey;
    }

    String formattedDate;
    if (scrap.date.isNotEmpty) {
      final rawDate = scrap.date;
      DateTime parsedDate = DateTime.parse("${rawDate}Z").toLocal();
      formattedDate = DateFormat('MM/dd/yyyy HH:mm:ss').format(parsedDate);
    } else {
      formattedDate = 'N/A';
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ScrapDetailPage(scrap: scrap, refreshScrap: refreshScrap),
            transitionDuration: motionProvider.reduceMotion
                ? const Duration(milliseconds: 100)
                : const Duration(milliseconds: 300),
            reverseTransitionDuration: motionProvider.reduceMotion
                ? const Duration(milliseconds: 100)
                : const Duration(milliseconds: 300),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  if (motionProvider.reduceMotion) {
                    return FadeTransition(opacity: animation, child: child);
                  }
                  return FadeTransition(opacity: animation, child: child);
                },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.05),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scrap.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Product: ${scrap.product}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Date: $formattedDate',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.confirmation_num,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Quantity: ${scrap.quantity}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
