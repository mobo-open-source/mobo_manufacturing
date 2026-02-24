import 'dart:convert';

import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:lottie/lottie.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoList/model/mo_event.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../LoginPage/services/storage_service.dart';
import '../../../../core/providers/motion_provider.dart';
import '../../../../globals.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../../services/manufacturing_order_service.dart';
import '../../../widgets/easy_filter.dart';
import '../../../widgets/search_filter_bar.dart';
import '../../../widgets/shimmer_loading.dart';
import '../../MoForm/models/user_model.dart';
import '../../MoForm/pages/mo_form_view_page.dart';
import '../bloc/mo_graph_event.dart';
import '../bloc/mo_list_bloc.dart';
import '../bloc/mo_list_event.dart';
import '../bloc/mo_list_state.dart';
import '../service/mo_list_service.dart';
import '../widgets/appointment_bottom_sheet.dart';
import 'create_mo_page.dart';

/// Top-level page that displays the list of Manufacturing Orders (MOs).
///
/// Delegates to `MOListView` for stateful behavior.
class MOListPage extends StatelessWidget {
  const MOListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MOListView();
  }
}

/// Stateful view that shows Manufacturing Orders in multiple modes:
/// • List view (paginated cards)
/// • Kanban view (grouped by status)
/// • Calendar view (scheduled MOs)
/// • Graph view (monthly quantity chart)
///
/// Features:
/// • Search bar + advanced filter/group-by bottom sheet
/// • Pull-to-refresh
/// • Pagination with page range indicator
/// • Floating action button to create new MO
/// • Dark mode support
/// • Reduced motion compatibility
class MOListView extends StatefulWidget {
  const MOListView({super.key});

  @override
  State<MOListView> createState() => MOListViewState();
}

class MOListViewState extends State<MOListView> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? selectedScheduleDate;
  DateTime? selectedEndDate;
  bool _isFilterApplied = false;
  late StorageService storageService;
  late MoListService moService;
  String? selectedStatus;
  String? selectedView = "list";
  int currentPage = 0;
  final int _itemsPerPage = 40;
  bool isLoadingMore = false;
  final ManufacturingOrderService _odooService = ManufacturingOrderService();
  List<MOEvent> _appointments = [];
  List<dynamic> graph = [];
  ChartType _chartType = ChartType.bar;
  Map<int, num> monthQty = {};
  String _selectedFilter = 'qty_produced';
  String errorMessage = '';
  List<dynamic> activityTypes = [];
  int? selectedActivityType;
  String? selectedActivityTypeName;
  List<UserModel> users = [];
  int? selectedUser;
  String? selectedUserName;
  DateTime? selectedDueDate;
  TextEditingController summaryController = TextEditingController();
  TextEditingController noteController = TextEditingController();
  bool hasFilters = false;
  bool hasGroupBy = false;
  final Map<String, String> filterTechnicalNames = {
    "To Do": "to_do",
    "Done": "done",
    "Cancelled": "cancel",
    "Draft": "draft",
    "Confirmed": "confirm",
    "Planned": "planned",
    "In Progress": "progress",
    "To Close": "close",
    "Awaiting Components": "waiting_components",
    "MO Ready": "mo_ready",
    "Delays": "delays",
    "Late Components": "late_components",
  };

  final Map<String, String> groupTechnicalNames = {
    "Product": "product",
    "Status": "status",
    "Procurement Group": "group",
  };
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<MOEvent> _getEventsForDay(DateTime day) {
    return _appointments.where((appt) {
      return !day.isBefore(appt.startTime) && !day.isAfter(appt.endTime);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    storageService = StorageService();
    moService = MoListService();
    loadCalendarMo();
    loadActivityData();
  }

  @override
  void dispose() {
    summaryController.dispose();
    noteController.dispose();
    super.dispose();
  }

  /// Loads activity types and users for filter bottom sheet
  Future<void> loadActivityData() async {
    await moService.initializeClient();
    final result = await moService.loadActivityType();
    final userResult = await moService.loadUsers();
    setState(() {
      activityTypes = result;
      users = userResult;
    });
  }

  /// Refreshes calendar appointments based on current filters/search
  Future<void> applyCalendarFilter(
    String searchTerm,
    DateTime? startDate,
    DateTime? endDate,
  ) async {
    await _odooService.initializeClient();

    final manufacturingOrders = await _odooService.fetchManufacturingOrders(
      0,
      0,
      searchTerm: searchTerm,
      selectedFilters: [],
    );

    _appointments = manufacturingOrders
        .where(
          (mo) =>
              mo['date_start'] != null &&
              mo['date_start'].toString().isNotEmpty,
        )
        .map((mo) {
          final rawStartDate = mo['date_start'];
          DateTime parsedStartDate = DateTime.parse(
            "${rawStartDate}Z",
          ).toLocal();

          final rawEndDate = mo['date_finished'];
          DateTime parsedEndDate = DateTime.parse("${rawEndDate}Z").toLocal();

          return MOEvent(
            startTime: parsedStartDate,
            endTime: parsedEndDate,
            subject: mo['name'] ?? 'MO',
            notes: jsonEncode(mo),
            color: AppStyle.primaryColor,
          );
        })
        .toList();
    graph = await manufacturingOrders;
    computeMonthlyQty(graph, _selectedFilter);
    setState(() {});
  }

  /// Loads initial calendar data (all MOs with dates)
  Future<void> loadCalendarMo() async {
    await _odooService.initializeClient();
    final manufacturingOrders = await _odooService.fetchManufacturingOrders(
      0,
      0,
      searchTerm: '',
      selectedFilters: [],
    );

    _appointments = manufacturingOrders
        .where(
          (mo) =>
              mo['date_start'] != null &&
              mo['date_start'].toString().isNotEmpty,
        )
        .map<MOEvent>((mo) {
          final rawStartDate = mo['date_start'];
          DateTime parsedStartDate = DateTime.parse(
            "${rawStartDate}Z",
          ).toLocal();

          final rawEndDate = mo['date_finished'];
          DateTime parsedEndDate = DateTime.parse("${rawEndDate}Z").toLocal();

          return MOEvent(
            startTime: parsedStartDate,
            endTime: parsedEndDate,
            subject: mo['name'] ?? 'MO',
            notes: jsonEncode(mo),
            color: AppStyle.primaryColor,
          );
        })
        .toList();

    graph = await manufacturingOrders;
    computeMonthlyQty(graph, _selectedFilter);

    setState(() {});
  }

  /// Fetches next/previous page of MOs via BLoC
  void _fetchPage(int page) {
    isLoadingMore = true;
    final currentState = context.read<MOListBloc>().state;
    final List<String> currentFilters = currentState is MOListLoaded
        ? currentState.selectedFilters
        : const [];
    context.read<MOListBloc>().add(
      FetchMOList(
        page: page,
        itemsPerPage: _itemsPerPage,
        searchTerm: _searchController.text,
        filters: currentFilters,
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        isLoadingMore = false;
      });
    });
  }

  /// Opens the filter & group-by bottom sheet
  void openFilterGroupBySheet(BuildContext context) {
    final bloc = context.read<MOListBloc>();
    final currentState = bloc.state;

    List<String> tempFilters = [];
    String? tempGroupBy;
    String? tempStartDateUnit;

    if (currentState is MOListLoaded) {
      tempFilters = List.from(currentState.selectedFilters);
      tempGroupBy = currentState.selectedGroupBy;
      tempStartDateUnit = currentState.selectedStartDateUnit;
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
                                      tempStartDateUnit = null;
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
                              bloc.add(ClearFilters());
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
                                ApplyFiltersAndGroupBy(
                                  filters: tempFilters,
                                  groupBy: tempGroupBy,
                                  startDateUnit: tempStartDateUnit,
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

  /// Returns human-readable status label from technical state
  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case "draft":
        return "Draft";
      case "confirmed":
        return "Confirmed";
      case "done":
        return "Done";
      case "progress":
        return "In Progress";
      case "to_close":
        return "To Close";
      case "cancel":
        return "Cancel";
      default:
        return status;
    }
  }

  /// Returns color for status chip/label
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "confirmed":
        return Colors.purple;
      case "draft":
        return Colors.black;
      case "progress":
        return Colors.blue;
      case "done":
        return Colors.green;
      case "to_close":
        return Colors.orange;
      case "cancel":
        return Colors.red;
      default:
        return Colors.black54;
    }
  }

  /// Refreshes the entire MO list via BLoC
  Future<void> refreshMo() async {
    context.read<MOListBloc>().add(const FetchMOList());
  }

  /// Extracts MO items from calendar appointments (for graph/filtering)
  List<Map<String, dynamic>> get moItemsFromAppointments {
    return _appointments.map((appointment) {
      if (appointment.notes != null) {
        return Map<String, dynamic>.from(jsonDecode(appointment.notes!));
      }
      return <String, dynamic>{};
    }).toList();
  }

  /// Builds the pagination bar with page info, prev/next arrows, and active filters/group info
  Widget _buildPaginationBar(MOListLoaded state, int totalPages) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 15,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0,horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Active filters/group badges
              Builder(
                builder: (context) {
                  hasFilters = state.selectedFilters.isNotEmpty;
                  hasGroupBy = (state.selectedGroupBy?.isNotEmpty ?? false);

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
                          color: isDark ? Colors.white70 : Colors.black54,
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
                      (key) => groupMap[key] == state.selectedGroupBy,
                      orElse: () => state.selectedGroupBy!.replaceAll('_', ' '),
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
                            color: isDark ? Colors.white70 : Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                state.selectedFilters.length.toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "Active",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.black : Colors.white,
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
                            color: isDark ? Colors.white70 : Colors.black,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                HugeIcons.strokeRoundedLayer,
                                size: 16,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                groupDisplayName ?? "Group",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.black : Colors.white,
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
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          state.pageRange,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '/',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${state.totalCount}',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap: state.currentPage > 0
                          ? () => _fetchPage(state.currentPage - 1)
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
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.grey[600] : Colors.grey[400]),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: InkWell(
                      onTap:
                          (state.currentPage + 1) * state.itemsPerPage <
                              state.totalCount
                          ? () => _fetchPage(state.currentPage + 1)
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
                              (state.currentPage + 1) * state.itemsPerPage <
                                  state.totalCount
                              ? (isDark ? Colors.white : Colors.black87)
                              : (isDark ? Colors.grey[600] : Colors.grey[400]),
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
    );
  }

  /// Builds a centered message with Lottie animation, title, subtitle, and optional button
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

  /// Builds a tappable card for a single Manufacturing Order
  Widget _buildMoCard(
    BuildContext context,
    Map<String, dynamic> item,
    bool isDark,
  ) {
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    DateTime? startDate;
    if (item['date_start'] != null &&
        item['date_start'].toString().isNotEmpty) {
      try {
        startDate = DateTime.parse("${item['date_start']}Z").toLocal();
      } catch (e) {
        startDate = null;
      }
    }

    String daysAgoText = '';
    if (startDate != null) {
      final difference = DateTime.now().difference(startDate).inDays;
      if (difference == 0) {
        daysAgoText = 'Today';
      } else if (difference == 1) {
        daysAgoText = '1 day ago';
      } else if (difference > 1) {
        daysAgoText = '$difference days ago';
      } else if (difference < 0) {
        daysAgoText = 'In ${-difference} day${-difference == 1 ? '' : 's'}';
      }
    }

    final statusLabel = _getStatusLabel(item['state'] ?? '');
    final statusColor = _getStatusColor(item['state'] ?? '');

    final productName =
        (item['product_id'] is List && item['product_id'].length > 1)
        ? item['product_id'][1].toString()
        : 'No Product';

    final qtyToProduce = item['product_qty']?.toString() ?? '0';
    final qtyProduced = item['qty_produced']?.toString() ?? '0';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MOFormViewPage(moItem: item, refreshMo: refreshMo),
              transitionDuration: motionProvider.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    if (motionProvider.reduceMotion) return child;
                    return FadeTransition(opacity: animation, child: child);
                  },
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? 'Unnamed MO',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              productName,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (daysAgoText.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                daysAgoText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[400]!
                                      : Colors.grey[700]!,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Text(
                            'To Produce: $qtyToProduce',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]!
                                  : Colors.grey[700]!,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Produced: $qtyProduced',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]!
                                  : Colors.grey[700]!,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(isDark ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds error UI with Lottie animation and retry button
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
            context.read<MOListBloc>().add(const FetchMOList());
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

  // ────────────────────────────────────────────────
  // Main build method.
  // ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return Column(
      children: [
        SearchFilterBar(
          searchController: _searchController,
          selectedScheduleDate: selectedScheduleDate,
          selectedEndDate: selectedEndDate,
          isFilterApplied: _isFilterApplied,
          selectedView: selectedView ?? '',
          onClearFilter: () {
            _searchController.clear();
            selectedScheduleDate = null;
            selectedEndDate = null;
            _isFilterApplied = false;
            applyCalendarFilter('', null, null);

            context.read<MOListBloc>().add(
              FetchMOList(searchTerm: _searchController.text, filters: []),
            );

            setState(() {});
          },
          onFilterApplied:
              (modalScheduledDate, modalEndDate, applied, searchTerm) {
                setState(() {
                  selectedScheduleDate = modalScheduledDate;
                  selectedEndDate = modalEndDate;
                  _isFilterApplied = applied;
                  currentPage = 0;
                });
                _fetchPage(0);
                applyCalendarFilter(
                  searchTerm,
                  modalScheduledDate,
                  modalEndDate,
                );
              },
        ),
        EasyFilterBar(
          selectedStatus: selectedStatus,
          onSelected: (status) {
            setState(() {
              selectedStatus = status;
            });
            applyCalendarFilter(
              _searchController.text,
              selectedScheduleDate,
              selectedEndDate,
            );
            final currentState = context.read<MOListBloc>().state;
            final List<String> currentFilters = currentState is MOListLoaded
                ? currentState.selectedFilters
                : const [];
            context.read<MOListBloc>().add(
              FetchMOList(
                searchTerm: _searchController.text,
                filters: currentFilters,
              ),
            );
          },
          selectedView: selectedView ?? 'list',
          onViewChanged: (view) {
            setState(() {
              selectedView = view;
            });
          },
        ),
        Expanded(
          child: BlocBuilder<MOListBloc, MOListState>(
            builder: (context, state) {
              if (state is MOListLoading) {
                return const ManufacturingOrderShimmer();
              }
              if (state is MOListError) {
                return _buildErrorState(isDark);
              }
              if (state is MOListLoaded) {
                final totalPages = (state.totalCount / state.itemsPerPage)
                    .ceil();
                if (state.moItems.isEmpty) {
                  hasFilters = state.selectedFilters.isNotEmpty;
                  hasGroupBy = (state.selectedGroupBy?.isNotEmpty ?? false);

                  return Column(
                    children: [
                      _buildPaginationBar(state, totalPages),

                      Expanded(
                        child: Center(
                          child: _buildCenteredLottie(
                            lottie: 'assets/empty_ghost.json',
                            title: 'No manufacturing order found',
                            subtitle: hasFilters
                                ? 'Try adjusting your filter'
                                : null,
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
                                            : AppStyle.primaryColor.withOpacity(
                                                0.3,
                                              ),
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
                                      context.read<MOListBloc>().add(
                                        ClearFilters(),
                                      );
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
                if (selectedView == "list") {
                  return Stack(
                    children: [
                      Column(
                        children: [
                          _buildPaginationBar(state, totalPages),
                          Expanded(
                            child: Stack(
                              children: [
                                if (state.selectedGroupBy != null &&
                                    state.selectedGroupBy!.isNotEmpty &&
                                    state.groupedMos.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: RefreshIndicator(
                                      onRefresh: () async => context
                                          .read<MOListBloc>()
                                          .add(const FetchMOList()),
                                      child: ListView.builder(
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        itemCount: state.groupedMos.length,
                                        itemBuilder: (context, index) {
                                          final group = state.groupedMos[index];
                                          final groupName =
                                              group["group"] as String;
                                          final groupMos =
                                              group["mos"]
                                                  as List<Map<String, dynamic>>;
                                          final isExpanded =
                                              state.groupExpanded[groupName] ??
                                              true;

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
                                                  onTap: () {
                                                    context
                                                        .read<MOListBloc>()
                                                        .add(
                                                          ToggleGroupExpanded(
                                                            groupName,
                                                          ),
                                                        );
                                                  },
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(
                                                      16,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                groupName,
                                                                style: TextStyle(
                                                                  color: isDark
                                                                      ? Colors
                                                                            .white
                                                                      : Colors
                                                                            .black87,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 15,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 4,
                                                              ),
                                                              Text(
                                                                '${groupMos.length} MO${groupMos.length != 1 ? 's' : ''}',
                                                                style: TextStyle(
                                                                  fontSize: 13,
                                                                  color: isDark
                                                                      ? Colors
                                                                            .grey[400]
                                                                      : Colors
                                                                            .grey[700],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Icon(
                                                          isExpanded
                                                              ? Icons
                                                                    .keyboard_arrow_up
                                                              : Icons
                                                                    .keyboard_arrow_down,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black54,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (isExpanded)
                                                  ...groupMos.map(
                                                    (mo) => Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8.0,
                                                          ),
                                                      child: _buildMoCard(
                                                        context,
                                                        mo,
                                                        isDark,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: RefreshIndicator(
                                      onRefresh: () async => context
                                          .read<MOListBloc>()
                                          .add(const FetchMOList()),
                                      child: ListView.builder(
                                        itemCount: state.moItems.length,
                                        itemBuilder: (context, index) {
                                          final item = state.moItems[index];

                                          DateTime? startDate;
                                          if (item['date_start'] != null) {
                                            startDate = DateTime.tryParse(
                                              item['date_start'],
                                            );
                                          }
                                          String daysAgoText = '';
                                          if (startDate != null) {
                                            final difference = DateTime.now()
                                                .difference(startDate)
                                                .inDays;
                                            if (difference == 0) {
                                              daysAgoText = 'Today';
                                            } else if (difference == 1) {
                                              daysAgoText = '1 day ago';
                                            } else {
                                              daysAgoText =
                                                  '$difference days ago';
                                            }
                                          }

                                          final statusLabel = _getStatusLabel(
                                            item['state'] ?? '',
                                          );
                                          final statusColor = _getStatusColor(
                                            item['state'] ?? '',
                                          );

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
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
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              title: Text(
                                                item['name'] ?? 'Unnamed',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppStyle.primaryColor,
                                                ),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (item['product_id'] != null)
                                                    Text(
                                                      'Product: ${item['product_id'][1]}',
                                                      softWrap: true,
                                                      overflow:
                                                          TextOverflow.visible,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        color: isDark
                                                            ? Colors.white54
                                                            : Colors.black54,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              trailing: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? Color(0xFF2A2A2A)
                                                      : statusColor.withOpacity(
                                                          0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : statusColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              onTap: () {
                                                Navigator.of(context).push(
                                                  PageRouteBuilder(
                                                    pageBuilder:
                                                        (
                                                          context,
                                                          animation,
                                                          secondaryAnimation,
                                                        ) => MOFormViewPage(
                                                          moItem: item,
                                                          refreshMo: refreshMo,
                                                        ),
                                                    transitionDuration:
                                                        motionProvider
                                                            .reduceMotion
                                                        ? Duration.zero
                                                        : const Duration(
                                                            milliseconds: 300,
                                                          ),
                                                    reverseTransitionDuration:
                                                        motionProvider
                                                            .reduceMotion
                                                        ? Duration.zero
                                                        : const Duration(
                                                            milliseconds: 300,
                                                          ),
                                                    transitionsBuilder:
                                                        (
                                                          context,
                                                          animation,
                                                          secondaryAnimation,
                                                          child,
                                                        ) {
                                                          if (motionProvider
                                                              .reduceMotion) {
                                                            return child;
                                                          }
                                                          return FadeTransition(
                                                            opacity: animation,
                                                            child: child,
                                                          );
                                                        },
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 16,
                                    right: 16,
                                    child: FloatingActionButton(
                                      onPressed: () {
                                        Navigator.of(context)
                                            .push(
                                              PageRouteBuilder(
                                                pageBuilder:
                                                    (
                                                      context,
                                                      animation,
                                                      secondaryAnimation,
                                                    ) =>
                                                        const CreateMOViewPage(),
                                                transitionDuration:
                                                    motionProvider.reduceMotion
                                                    ? Duration.zero
                                                    : const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                reverseTransitionDuration:
                                                    motionProvider.reduceMotion
                                                    ? Duration.zero
                                                    : const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                transitionsBuilder:
                                                    (
                                                      context,
                                                      animation,
                                                      secondaryAnimation,
                                                      child,
                                                    ) {
                                                      if (motionProvider
                                                          .reduceMotion) {
                                                        return child;
                                                      }
                                                      return FadeTransition(
                                                        opacity: animation,
                                                        child: child,
                                                      );
                                                    },
                                              ),
                                            )
                                            .then((result) {
                                              if (result == true) {
                                                CustomSnackbar.showSuccess(
                                                  context,
                                                  'Manufacturing Order created successfully!',
                                                );
                                                context.read<MOListBloc>().add(
                                                  const FetchMOList(),
                                                );
                                              }
                                            });
                                      },
                                      backgroundColor: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      tooltip: 'Add Manufacturing Order',
                                      child: Stack(
                                        alignment: Alignment.topRight,
                                        clipBehavior: Clip.none,
                                        children: [
                                          Icon(
                                            HugeIcons.strokeRoundedPlusSign,
                                            size: 18,
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                if (selectedView == "kanban") {
                  final groupedItems = <String, List<Map<String, dynamic>>>{};
                  for (var item in state.moItems) {
                    final status = item['state'] ?? 'unknown';
                    groupedItems.putIfAbsent(status, () => []).add(item);
                  }

                  return Column(
                    children: [
                      _buildPaginationBar(state, totalPages),
                      Expanded(
                        child: Stack(
                          children: [
                            RefreshIndicator(
                              onRefresh: () async => context
                                  .read<MOListBloc>()
                                  .add(const FetchMOList()),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: groupedItems.entries.map((
                                        entry,
                                      ) {
                                        final status = entry.key;
                                        final items = entry.value;
                                        final color = _getStatusColor(status);
                                        final statusLabel = _getStatusLabel(
                                          status,
                                        );

                                        return Container(
                                          width: 280,
                                          margin: const EdgeInsets.all(8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1B1A1A)
                                                : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: color.withOpacity(0.3),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: double.infinity,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 8,
                                                        horizontal: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: color.withOpacity(
                                                      0.15,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      statusLabel.toUpperCase(),
                                                      style: TextStyle(
                                                        color: color,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 8),

                                              ...items.map((item) {
                                                final rawDate =
                                                    item['date_start'];
                                                DateTime parsedDate =
                                                    DateTime.parse(
                                                      "${rawDate}Z",
                                                    ).toLocal();
                                                String formattedDate =
                                                    DateFormat(
                                                      'MM/dd/yyyy HH:mm:ss',
                                                    ).format(parsedDate);
                                                String startDate =
                                                    formattedDate;

                                                return InkWell(
                                                  onTap: () {
                                                    Navigator.of(context).push(
                                                      PageRouteBuilder(
                                                        pageBuilder:
                                                            (
                                                              context,
                                                              animation,
                                                              _,
                                                            ) => MOFormViewPage(
                                                              moItem: item,
                                                              refreshMo:
                                                                  refreshMo,
                                                            ),
                                                        transitionDuration:
                                                            motionProvider
                                                                .reduceMotion
                                                            ? Duration.zero
                                                            : const Duration(
                                                                milliseconds:
                                                                    300,
                                                              ),
                                                        transitionsBuilder:
                                                            (
                                                              context,
                                                              animation,
                                                              _,
                                                              child,
                                                            ) {
                                                              return motionProvider
                                                                      .reduceMotion
                                                                  ? child
                                                                  : FadeTransition(
                                                                      opacity:
                                                                          animation,
                                                                      child:
                                                                          child,
                                                                    );
                                                            },
                                                      ),
                                                    );
                                                  },
                                                  child: SizedBox(
                                                    width: double.infinity,
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 6,
                                                          ),
                                                      padding:
                                                          const EdgeInsets.all(
                                                            10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isDark
                                                            ? const Color(
                                                                0xFF2A2A2A,
                                                              )
                                                            : Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.05,
                                                                ),
                                                            blurRadius: 4,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ],
                                                        border: Border.all(
                                                          color: color
                                                              .withOpacity(0.2),
                                                        ),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            item['product_id'][1] ??
                                                                'Unnamed',
                                                            style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 13,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : AppStyle
                                                                        .primaryColor,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            "${item['product_qty'] ?? '0'} Units",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                              color: isDark
                                                                  ? Colors
                                                                        .white54
                                                                  : Colors
                                                                        .black54,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            "${item['name'] ?? ''}  •  $startDate",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                              color: isDark
                                                                  ? Colors
                                                                        .white38
                                                                  : Colors
                                                                        .black54,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton(
                                onPressed: () {
                                  Navigator.of(context)
                                      .push(
                                        PageRouteBuilder(
                                          pageBuilder:
                                              (context, animation, _) =>
                                                  const CreateMOViewPage(),
                                          transitionDuration:
                                              motionProvider.reduceMotion
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 300,
                                                ),
                                          transitionsBuilder:
                                              (context, animation, _, child) {
                                                return motionProvider
                                                        .reduceMotion
                                                    ? child
                                                    : FadeTransition(
                                                        opacity: animation,
                                                        child: child,
                                                      );
                                              },
                                        ),
                                      )
                                      .then((result) {
                                        if (result == true) {
                                          CustomSnackbar.showSuccess(
                                            context,
                                            'Manufacturing Order created successfully!',
                                          );
                                        }
                                      });
                                },
                                backgroundColor: isDark
                                    ? Colors.white
                                    : AppStyle.primaryColor,
                                child: Icon(
                                  HugeIcons.strokeRoundedPlusSign,
                                  size: 18,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                if (selectedView == "calendar") {
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<MOListBloc>().add(const FetchMOList());
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black26
                                        : Colors.black.withOpacity(0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TableCalendar(
                                firstDay: DateTime.utc(2020),
                                lastDay: DateTime.utc(2030, 12, 31),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) =>
                                    isSameDay(_selectedDay, day),
                                calendarFormat: CalendarFormat.month,
                                startingDayOfWeek: StartingDayOfWeek.sunday,

                                headerStyle: HeaderStyle(
                                  titleCentered: true,
                                  formatButtonVisible: false,
                                  titleTextStyle: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  leftChevronIcon: Icon(
                                    Icons.chevron_left,
                                    color: isDark ? Colors.white70 : null,
                                  ),
                                  rightChevronIcon: Icon(
                                    Icons.chevron_right,
                                    color: isDark ? Colors.white70 : null,
                                  ),
                                ),

                                calendarStyle: CalendarStyle(
                                  selectedDecoration: BoxDecoration(
                                    color: AppStyle.primaryColor.withOpacity(
                                      0.18,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  selectedTextStyle: const TextStyle(
                                    color: AppStyle.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  todayDecoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                      width: 2,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  todayTextStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  outsideDaysVisible: true,
                                ),

                                calendarBuilders: CalendarBuilders(
                                  defaultBuilder: (context, day, focusedDay) {
                                    final hasEvents = _getEventsForDay(
                                      day,
                                    ).isNotEmpty;

                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedDay = day;
                                          _focusedDay = day;
                                        });
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${day.day}',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            ),
                                          ),
                                          if (hasEvents) ...[
                                            const SizedBox(height: 2),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color: AppStyle.primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _selectedDay = selectedDay;
                                    _focusedDay = focusedDay;
                                  });
                                },
                                onPageChanged: (focusedDay) {
                                  _focusedDay = focusedDay;
                                },
                              ),
                            ),
                          ),
                        ),
                        if (_selectedDay != null) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2A2A2A)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.6)
                                            : AppStyle.primaryColor.withOpacity(
                                                0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        HugeIcons.strokeRoundedCalendar03,
                                        color: isDark
                                            ? Colors.white
                                            : AppStyle.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            DateFormat(
                                              'MMM d, yyyy',
                                            ).format(_selectedDay!),
                                            style: TextStyle(
                                              fontSize: 16,
                                              height: 1.0,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            _getEventsForDay(
                                                  _selectedDay!,
                                                ).isEmpty
                                                ? 'No MOs scheduled for this day'
                                                : '${_getEventsForDay(_selectedDay!).length} MO(s) scheduled',
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.05,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF2A2A2A)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.6)
                                            : AppStyle.primaryColor.withOpacity(
                                                0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        HugeIcons.strokeRoundedCalendar03,
                                        color: isDark
                                            ? Colors.white
                                            : AppStyle.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Select a date',
                                            style: TextStyle(
                                              fontSize: 16,
                                              height: 1.0,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            'Tap a date to view MO(s)',
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.05,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        SliverToBoxAdapter(
                          child: SizedBox(height: 8),
                        ),
                        if (_selectedDay != null)
                          SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final event = _getEventsForDay(
                                _selectedDay!,
                              )[index];

                              final timeStr =
                                  (event.startTime != null &&
                                      event.endTime != null)
                                  ? '${DateFormat('hh:mm a').format(event.startTime!)}'
                                        ' - ${DateFormat('hh:mm a').format(event.endTime!)}'
                                  : '';

                              final item = event.notes != null
                                  ? Map<String, dynamic>.from(
                                      jsonDecode(event.notes!),
                                    )
                                  : <String, dynamic>{};

                              final label =
                                  item['code'] ?? event.subject ?? 'MO Item';

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16,vertical: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black26
                                            : Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        backgroundColor: isDark
                                            ? const Color(0xFF1F1F1F)
                                            : Colors.white,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                        ),
                                        builder: (_) => AppointmentBottomSheet(
                                          appointment: event,
                                          item: item,
                                          onEdit: () {
                                            Navigator.pop(context);
                                            Navigator.of(context).push(
                                              PageRouteBuilder(
                                                pageBuilder:
                                                    (
                                                      context,
                                                      animation,
                                                      secondaryAnimation,
                                                    ) => MOFormViewPage(
                                                      moItem: item,
                                                    ),
                                                transitionDuration:
                                                    motionProvider.reduceMotion
                                                    ? Duration.zero
                                                    : const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                reverseTransitionDuration:
                                                    motionProvider.reduceMotion
                                                    ? Duration.zero
                                                    : const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                transitionsBuilder:
                                                    (
                                                      context,
                                                      animation,
                                                      secondaryAnimation,
                                                      child,
                                                    ) {
                                                      if (motionProvider
                                                          .reduceMotion) {
                                                        return child;
                                                      }
                                                      return FadeTransition(
                                                        opacity: animation,
                                                        child: child,
                                                      );
                                                    },
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }, childCount: _getEventsForDay(_selectedDay!).length),
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  );
                }

                if (selectedView == "graph") {
                  final maxValue = monthQty.values.isEmpty
                      ? 10
                      : monthQty.values.reduce((a, b) => a > b ? a : b);

                  final stepSize = (maxValue <= 5)
                      ? 1
                      : (maxValue <= 10)
                      ? 2
                      : (maxValue <= 50)
                      ? 5
                      : 10;

                  final roundedMaxY = ((maxValue / stepSize).ceil()) * stepSize;

                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: RefreshIndicator(
                      onRefresh: () async =>
                          context.read<MOListBloc>().add(const FetchMOList()),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[850]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.grey[500]!
                                        : Colors.grey[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton2<String>(
                                    isExpanded: false,
                                    value: _selectedFilter,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontSize: 13,
                                    ),
                                    buttonStyleData: const ButtonStyleData(
                                      height: 42,
                                      padding: EdgeInsets.only(
                                        left: 0,
                                        right: 6,
                                      ),
                                    ),
                                    iconStyleData: const IconStyleData(
                                      icon: Icon(Icons.keyboard_arrow_down, size: 16),
                                      iconSize: 16,
                                    ),

                                    dropdownStyleData: DropdownStyleData(
                                      maxHeight: 200,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: isDark ? Colors.grey[900] : Colors.white,
                                      ),
                                    ),

                                    items:
                                        const [
                                          'product_uom_qty',
                                          'qty_produced',
                                          'product_qty',
                                        ].map((filter) {
                                          String label;
                                          if (filter == 'product_uom_qty') {
                                            label = 'Product Quantity';
                                          } else if (filter == 'qty_produced') {
                                            label = 'Quantity Produced';
                                          } else {
                                            label = 'Quantity To Produce';
                                          }

                                          return DropdownMenuItem<String>(
                                            value: filter,
                                            child: Transform.translate(
                                              offset: const Offset(-6, 0),
                                              child: Text(label),
                                            ),
                                          );
                                        }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedFilter = value;
                                          computeMonthlyQty(
                                            graph,
                                            _selectedFilter,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),

                              const Spacer(),
                              Row(
                                children: [
                                  _buildChartTypeButton(
                                    icon: Icons.bar_chart,
                                    type: ChartType.bar,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildChartTypeButton(
                                    icon:
                                        HugeIcons.strokeRoundedChartLineData03,
                                    type: ChartType.line,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2A2A)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  8,
                                ),
                                child: _buildChart(
                                  monthQty,
                                  _chartType,
                                  stepSize,
                                  roundedMaxY,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChartTypeButton({
    required IconData icon,
    required ChartType type,
    required bool isDark,
  }) {
    final bool selected = _chartType == type;
    return InkWell(
      onTap: () => setState(() => _chartType = type),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.grey[850] : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected
              ? (isDark ? Colors.black : Colors.white)
              : (isDark ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  void computeMonthlyQty(List<dynamic> moItems, String field) {
    monthQty = {};
    for (var mo in moItems) {
      if (mo['date_start'] != null) {
        final date = DateTime.tryParse(mo['date_start']);
        if (date != null) {
          final month = date.month;
          final qty = mo[field] ?? 0;
          monthQty[month] = (monthQty[month] ?? 0) + qty;
        }
      }
    }
  }

  Widget _buildChart(
    Map<int, num> monthQty,
    ChartType chartType,
    int stepSize,
    int roundedMaxY,
  ) {
    final barGroups = monthQty.entries.map((e) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: e.value.toDouble(),
            color: isDark ? Colors.white : AppStyle.primaryColor,
            width: 30,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(6),
              bottom: Radius.zero,
            ),
          ),
        ],
      );
    }).toList();

    final lineSpots = monthQty.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    switch (chartType) {
      case ChartType.bar:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return BarChart(
          BarChartData(
            maxY: roundedMaxY.toDouble(),
            barGroups: barGroups,

            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: stepSize.toDouble(),
              getDrawingHorizontalLine: (value) => FlLine(
                color: isDark
                    ? Colors.grey.shade700.withOpacity(0.5)
                    : Colors.grey.shade400.withOpacity(0.7),
                strokeWidth: 1.0,
                dashArray: [7, 5],
              ),
            ),

            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(
                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                  width: 1,
                ),
                bottom: BorderSide(
                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                  width: 1,
                ),
                top: BorderSide.none,
                right: BorderSide.none,
              ),
            ),

            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: stepSize.toDouble(),
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 8,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final monthIndex = value.toInt();
                    if (monthQty.containsKey(monthIndex)) {
                      return Text(
                        monthNames[monthIndex],
                        style: TextStyle(
                          fontSize: 8,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
          ),
        );

      case ChartType.line:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return LineChart(
          LineChartData(
            minY: 0,
            maxY: roundedMaxY.toDouble(),
            lineBarsData: [
              LineChartBarData(
                spots: lineSpots,
                isCurved: true,
                color: isDark ? Colors.white : AppStyle.primaryColor,
                barWidth: 3,
              ),
            ],
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: false,
              horizontalInterval: stepSize.toDouble(),
              getDrawingHorizontalLine: (value) => FlLine(
                color: isDark
                    ? Colors.grey.shade700.withOpacity(0.5)
                    : Colors.grey.shade400.withOpacity(0.7),
                strokeWidth: 1.0,
                dashArray: [7, 5],
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                left: BorderSide(
                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                  width: 1,
                ),
                bottom: BorderSide(
                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                  width: 1,
                ),
                top: BorderSide.none,
                right: BorderSide.none,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: stepSize.toDouble(),
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 8,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final monthIndex = value.toInt();
                    if (monthQty.containsKey(monthIndex)) {
                      return Text(
                        monthNames[monthIndex],
                        style: TextStyle(
                          fontSize: 8,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
          ),
        );
    }
  }
}
