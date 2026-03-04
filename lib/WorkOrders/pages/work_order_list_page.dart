import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_manufacturing_app/shared/widgets/snackbar.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../MO/pages/MoForm/models/work_center.dart';
import '../../Rating/review_service.dart';
import '../../globals.dart';
import '../data/work_order_timer_manager.dart';
import '../model/lost_wo_reason.dart';
import '../model/work_order.dart';
import '../providers/work_order_provider.dart';
import '../widget/work_order_list_tile.dart';

/// Main screen displaying the list of Work Orders (mrp.workorder records).
///
/// Features:
/// - Paginated list with pull-to-refresh
/// - Live/debounced search
/// - Advanced filter (status) & group-by (MO, Work Center, Status) bottom sheet
/// - Grouped view support with expand/collapse
/// - Real-time timer display for running work orders
/// - Start/Pause/Finish actions with loading states
/// - Empty/error states with Lottie animations
/// - Pagination controls with range display
class WorkOrderListPage extends StatefulWidget {
  const WorkOrderListPage({super.key});

  @override
  State<WorkOrderListPage> createState() => _WorkOrderListPageState();
}

class _WorkOrderListPageState extends State<WorkOrderListPage> {
  // Blocked work orders (for UI indication)
  Set<int> blockedIds = {};

  // Loading & error states
  bool isLoading = true;
  String? errorMessage;

  // Lost reason dropdown data
  List<LostWoReason> lostReason = [];
  int? selectedReason;
  String? selectedReasonName;

  // UI timers
  Timer? _timer;
  final timerManager = WorkOrderTimerManager();
  Timer? _uiTimer;

  // Pagination & search
  int totalCount = 0;
  String pageRange = '0-0';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Initial loading flag
  bool isInitialLoading = true;
  bool isFilterApplied = false;

  // Reference data
  List<WorkCenter> workCenter = [];

  // Loading states per work order
  Map<int, bool> isLoadingMap = {};
  Map<int, bool> isDoneLoadingMap = {};

  late final WorkOrderProvider provider;

  // Filter/group badges visibility
  bool hasFilters = false;
  bool hasGroupBy = false;

  // Status filter options (technical names)
  final Map<String, String> filterTechnicalNames = {
    "In Progress": "progress",
    "Ready": "ready",
    "Waiting": "waiting",
    "Pending": "pending",
    "Draft": "draft",
    "Finished": "finished",
    "Late": "late",
  };

  // Grouping options
  final Map<String, String> groupTechnicalNames = {
    "Manufacturing Order": "production_id",
    "Work Center": "workcenter_id",
    "Status": "state",
  };

  @override
  void initState() {
    super.initState();
    provider = context.read<WorkOrderProvider>();

    // UI refresh timer for real-time duration display
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Debounced search listener
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _timer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Handles live search input with debounce (500ms delay)
  Future<void> _onSearchChanged() async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<WorkOrderProvider>().setSearchText(
        _searchController.text.trim(),
      );
    });
  }

  /// Builds the persistent search bar with filter icon trigger
  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
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
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xffF8FAFB),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            hintText: 'Search Work Orders...',
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
    );
  }

  /// Opens the advanced filter & group-by bottom sheet modal
  void openFilterGroupBySheet(BuildContext context) {
    final provider = context.read<WorkOrderProvider>();

    List<String> tempFilters = List.from(provider.selectedStatuses);
    String? tempGroupBy = provider.groupBy;

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

                  // Action buttons
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
                              provider.clearFilters();
                              provider.setGroupBy(null);
                              Navigator.pop(context);
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
                              provider.setStatusFilter(tempFilters);
                              provider.setGroupBy(tempGroupBy);
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

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkOrderProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          body: Column(
            children: [
              _buildSearchBar(isDark),

              // Pagination & filter/group badges
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
                        // Filter/Group badges
                        Builder(
                          builder: (context) {
                            hasFilters = provider.selectedStatuses.isNotEmpty;
                            hasGroupBy =
                                (provider.groupBy?.isNotEmpty ?? false);

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
                                "Manufacturing Order": "production_id",
                                "Work Center": "workcenter_id",
                                "Status": "state",
                              };

                              groupDisplayName = groupMap.keys.firstWhere(
                                (key) => groupMap[key] == provider.groupBy,
                                orElse: () =>
                                    provider.groupBy!.replaceAll('_', ' '),
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
                                          provider.selectedStatuses.length
                                              .toString(),
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

                        // Pagination controls
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
                                    provider.pageRange,
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
                                    '${provider.totalCount}',
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
                                onTap: provider.hasPreviousPage
                                    ? () => provider.previousPage()
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    HugeIcons.strokeRoundedArrowLeft01,
                                    size: 20,
                                    color: provider.hasPreviousPage
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
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: InkWell(
                                onTap: provider.hasNextPage
                                    ? () => provider.nextPage()
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 4,
                                  ),
                                  child: Icon(
                                    HugeIcons.strokeRoundedArrowRight01,
                                    size: 20,
                                    color: provider.hasNextPage
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

              // Main content area
              Expanded(
                child: provider.groupBy != null
                    ? _buildGroupedWorkOrdersList(isDark)
                    : _buildWorkOrdersList(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Builds full-screen error state with Lottie animation and retry button
  Widget _buildErrorState(bool isDark) {
    return Center(
      child: _buildCenteredLottie(
        lottie: 'assets/Error_404.json',
        title: 'Something went wrong',
        subtitle: 'Tap Retry to refresh',
        isDark: isDark,
        button: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white : AppStyle.primaryColor,
            side: BorderSide(
              color: isDark
                  ? Colors.grey[600]!
                  : AppStyle.primaryColor.withOpacity(0.3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            context.read<WorkOrderProvider>().initialize();
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

  /// Builds the grouped work orders list view when grouping is active
  Widget _buildGroupedWorkOrdersList(bool isDark) {
    final groupedItems = buildGroupedWorkOrders(
      items: provider.workOrders,
      groupBy: provider.groupBy!,
    );

    return provider.hasError
        ? _buildErrorState(isDark)
        : provider.isSearching || provider.isLoading
        ? _buildShimmerListForSearch()
        : provider.workOrders.isEmpty
        ? _buildEmptyState(isDark)
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: groupedItems.length,
            itemBuilder: (context, index) {
              final group = groupedItems[index];
              final groupName = group['group'] as String;
              final groupItems = group['items'] as List<WorkOrder>;
              final isExpanded = provider.groupExpanded[groupName] ?? true;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => provider.toggleGroup(groupName),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
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
                        (wo) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: WorkOrderListTile(
                            workOrder: wo,
                            isBlocked: blockedIds.contains(wo.id),
                            isStarted: provider.isTimerRunning(wo.id),
                            realDuration: provider.isTimerRunning(wo.id)
                                ? provider.getElapsedTime(wo.id)
                                : provider.parseFormattedDuration(
                                    wo.formattedDuration,
                                  ),
                            onStart: () async {
                              setState(() => isLoadingMap[wo.id] = true);
                              try {
                                await provider.startWorkOrder(
                                  wo.id,
                                  wo.formattedDuration,
                                );
                                ReviewService().trackSignificantEvent();
                                Future.delayed(const Duration(seconds: 3), () {
                                  ReviewService().checkAndShowRating(context);
                                });
                              } finally {
                                if (mounted) {
                                  setState(() => isLoadingMap[wo.id] = false);
                                }
                              }
                            },

                            onPause: () async {
                              setState(() => isLoadingMap[wo.id] = true);
                              try {
                                await provider.pauseWorkOrder(wo.id);
                                ReviewService().trackSignificantEvent();
                                Future.delayed(const Duration(seconds: 3), () {
                                  ReviewService().checkAndShowRating(context);
                                });
                              } finally {
                                if (mounted) {
                                  setState(() => isLoadingMap[wo.id] = false);
                                }
                              }
                            },

                            onDone: () async {
                              setState(() => isDoneLoadingMap[wo.id] = true);
                              try {
                                await provider.finishWorkOrder(wo.id);
                                ReviewService().trackSignificantEvent();
                                Future.delayed(const Duration(seconds: 3), () {
                                  ReviewService().checkAndShowRating(context);
                                });
                              } finally {
                                if (mounted) {
                                  setState(
                                    () => isDoneLoadingMap[wo.id] = false,
                                  );
                                }
                              }
                            },
                            isLoading: isLoadingMap[wo.id] ?? false,
                            isDoneLoading: isDoneLoadingMap[wo.id] ?? false,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
  }

  /// Builds a centered placeholder with Lottie animation, title, subtitle, and optional action button
  /// Used for empty states, error states, and loading fallbacks
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

  /// Builds shimmer placeholder list for search/filter loading states
  Widget _buildShimmerListForSearch() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
    );
  }

  /// Builds full-screen empty state with Lottie animation and optional clear filters button
  Widget _buildEmptyState(bool isDark) {
    bool hasFilters =
        provider.selectedStatuses.isNotEmpty || provider.groupBy != null;

    return RefreshIndicator(
      onRefresh: () => provider.loadWorkOrders(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildCenteredLottie(
              lottie: 'assets/empty_ghost.json',
              title: 'No work orders found',
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
                        provider.clearFilters();
                        provider.setGroupBy(null);
                        provider.loadWorkOrders();
                      },
                      child: Text(
                        'Clear All Filters',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Human-readable status label mapping
  String _humanStatus(String raw) {
    switch (raw) {
      case 'pending':
        return 'Waiting for another WO';
      case 'waiting':
        return 'Waiting for Components';
      case 'ready':
        return 'Ready';
      case 'progress':
        return 'In Progress';
      case 'done':
        return 'Finished';
      case 'cancel':
        return 'Cancelled';
      default:
        return raw;
    }
  }

  List<Map<String, dynamic>> buildGroupedWorkOrders({
    required List<WorkOrder> items,
    required String groupBy,
  }) {
    final Map<String, List<WorkOrder>> groupedMap = {};

    for (final wo in items) {
      String groupKey;

      switch (groupBy) {
        case 'production_id':
          groupKey = wo.mo?.trim().isNotEmpty == true ? wo.mo! : 'None';
          break;

        case 'workcenter_id':
          groupKey = wo.workCenter?.trim().isNotEmpty == true
              ? wo.workCenter!
              : 'None';
          break;

        case 'state':
          if (wo.status != null && wo.status!.trim().isNotEmpty) {
            groupKey = _humanStatus(wo.status!);
          } else {
            groupKey = 'None';
          }
          break;
        default:
          groupKey = 'None';
      }

      groupedMap.putIfAbsent(groupKey, () => []).add(wo);
    }

    return groupedMap.entries
        .map((e) => {'group': e.key, 'items': e.value})
        .toList();
  }

  /// Builds the standard (non-grouped) work orders list view
  Widget _buildWorkOrdersList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () => provider.loadWorkOrders(),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: provider.hasError
                      ? _buildErrorState(isDark)
                      : provider.isSearching || provider.isLoading
                      ? _buildShimmerListForSearch()
                      : provider.workOrders.isEmpty
                      ? _buildEmptyState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: provider.workOrders.length,
                          itemBuilder: (context, index) {
                            final wo = provider.workOrders[index];

                            final isLoading = isLoadingMap[wo.id] ?? false;
                            final isDoneLoading =
                                isDoneLoadingMap[wo.id] ?? false;

                            return WorkOrderListTile(
                              workOrder: wo,
                              isBlocked: blockedIds.contains(wo.id),
                              isStarted: provider.isTimerRunning(wo.id),
                              realDuration: provider.isTimerRunning(wo.id)
                                  ? provider.getElapsedTime(wo.id)
                                  : provider.parseFormattedDuration(
                                      wo.formattedDuration,
                                    ),
                              onStart: () async {
                                setState(() => isLoadingMap[wo.id] = true);
                                try {
                                  final success = await provider.startWorkOrder(
                                    wo.id,
                                    wo.formattedDuration,
                                  );
                                  if (!success &&
                                      provider.alertMessage != null) {
                                    CustomSnackbar.showError(
                                      context,
                                      provider.alertMessage!,
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => isLoadingMap[wo.id] = false);
                                  }
                                }
                              },
                              onPause: () async {
                                setState(() => isLoadingMap[wo.id] = true);
                                try {
                                  final success = await provider.pauseWorkOrder(wo.id);
                                  if (!success &&
                                      provider.alertMessage != null) {
                                    CustomSnackbar.showError(
                                      context,
                                      provider.alertMessage!,
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => isLoadingMap[wo.id] = false);
                                  }
                                }
                              },
                              onDone: () async {
                                setState(() => isDoneLoadingMap[wo.id] = true);
                                try {
                                  final success = await provider.finishWorkOrder(wo.id);
                                  if (!success &&
                                      provider.alertMessage != null) {
                                    CustomSnackbar.showError(
                                      context,
                                      provider.alertMessage!,
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(
                                      () => isDoneLoadingMap[wo.id] = false,
                                    );
                                  }
                                }
                              },
                              isLoading: isLoading,
                              isDoneLoading: isDoneLoading,
                            );
                          },
                        ),
                ),
                if (provider.isPaginationLoading)
                  Center(
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      color: AppStyle.primaryColor,
                      size: 50,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
