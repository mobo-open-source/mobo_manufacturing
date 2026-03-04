import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../Rating/review_service.dart';
import '../../../../core/navigation/data_loss_warning_dialog.dart';
import '../../../../globals.dart';
import 'package:hive/hive.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../Dashboard/services/settings_storage_service.dart';
import '../../../widgets/shimmer_form_loading.dart';
import '../../MoList/service/hive/models.dart';
import '../../MoList/service/mo_list_service.dart';
import '../bloc/mo_form/mo_form_bloc.dart';
import '../bloc/mo_form/mo_form_event.dart';
import '../bloc/mo_form/mo_form_state.dart';
import '../models/bom.dart';
import '../models/mo_work_order.dart';
import '../models/product.dart';
import '../models/stock_move.dart';
import '../models/user_model.dart';
import '../models/work_center.dart';
import '../service/app_lifecycle_service.dart';
import '../service/background_timer_service.dart';
import '../service/mo_form_service.dart';
import '../widgets/mo_form/detail_row_widget.dart';
import '../widgets/mo_form/dialogs/scrap_products_dialog.dart';
import '../widgets/mo_form/product_table_widget.dart';
import '../widgets/mo_form/smart_tabs_widget.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/snackbar.dart';

/// Main view page for displaying and editing Manufacturing Orders (MO).
///
/// This page shows detailed information about a manufacturing order,
/// allows editing core fields (when in draft), displays components (stock moves),
/// and manages work orders with start/pause/done functionality and real-time
/// duration tracking.
class MOFormViewPage extends StatefulWidget {
  final Map<String, dynamic> moItem;
  final Future<void> Function()? refreshMo;

  const MOFormViewPage({super.key, required this.moItem, this.refreshMo});

  @override
  State<MOFormViewPage> createState() => _MOFormViewPageState();
}

class _MOFormViewPageState extends State<MOFormViewPage> {
  bool enableManufacturingDeadline = true;
  bool enableOrderDeadline = true;
  bool showOverviewSmartTab = true;
  bool showProductMoveSmartTab = true;
  bool showTraceabilitySmartTab = true;
  String? editingField;
  List<dynamic> moItem = [];
  List<dynamic> scrapProduct = [];
  List<Bom> billOfMaterial = [];
  List<UserModel> users = [];
  List<Product> products = [];
  List<WorkCenter> workCenters = [];
  List<MoWorkOrder> workOrders = [];
  List<StockMove> moveProducts = [];
  int? updatedProduct;
  int? updatedBom;
  int? updatedUser;
  String? updatedQty;
  DateTime? updatedScheduleDate;
  DateTime? updatedEndDate;
  Set<int> blockedWorkOrderIds = {};
  bool isEditing = false;
  bool isWorkOrder = false;
  List<bool> isStartLoading = [];
  List<bool> isPauseLoading = [];
  List<bool> isDoneLoading = [];
  List<bool> isRealUpdate = [];
  String errorMessage = '';
  late BackgroundTimerService _timerService;
  StreamSubscription<Map<int, Duration>>? _durationSubscription;
  late AppLifecycleService _lifecycleService;

  // ────────────────────────────────────────────────────────────────
  // Lifecycle & Initialization
  // ────────────────────────────────────────────────────────────────

  /// Initializes timer service, lifecycle observer, and loads initial data
  @override
  void initState() {
    super.initState();
    _timerService = BackgroundTimerService();
    _timerService.initialize();

    _lifecycleService = AppLifecycleService(_timerService);
    _lifecycleService.startListening();

    _setupDurationListener();
    _loadOnlineData();
  }

  /// Sets up stream listener for real-time duration updates from background timer
  void _setupDurationListener() {
    _durationSubscription = _timerService.durationStream.listen((durations) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _lifecycleService.stopListening();
    super.dispose();
  }

  /// Reloads work orders when dependencies change
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (moItem.isNotEmpty) {
      _refreshWorkOrders();
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Data Loading & Refresh
  // ────────────────────────────────────────────────────────────────

  /// Refreshes the list of work orders for current MO from backend
  Future<void> _refreshWorkOrders() async {
    final odooMoService = MoFormService();
    await odooMoService.initializeClient();
    final moId = int.parse(widget.moItem['id'].toString());
    final updatedWorkOrders = await odooMoService.loadWorkOrders(moId);

    if (mounted) {
      setState(() {
        workOrders = updatedWorkOrders;
        isRealUpdate = List.filled(workOrders.length, false);
      });
    }
  }

  /// Loads all necessary data (MO, products, BOMs, users, work centers)
  /// Uses Hive cache when available, falls back to network fetch
  Future<void> _loadOnlineData() async {
    try {
      final productBox = await Hive.openBox<HiveProduct>('products');
      final bomBox = await Hive.openBox<HiveBom>('bom');
      final userBox = await Hive.openBox<HiveUserModel>('users');
      final workCenterBox = await Hive.openBox<HiveWorkCenter>('workCenters');
      final odooService = MoFormService();
      await odooService.initializeClient();
      final moId = int.parse(widget.moItem['id'].toString());
      final productTmplId = widget.moItem['product_tmpl_id'][0] as int;
      moItem = await odooService.loadMo(moId);
      workOrders = await odooService.loadWorkOrders(moId);
      billOfMaterial = await odooService.loadBomId(productTmplId);
      isStartLoading = List.filled(workOrders.length, false);
      isPauseLoading = List.filled(workOrders.length, false);
      isDoneLoading = List.filled(workOrders.length, false);
      isRealUpdate = List.filled(workOrders.length, false);

      if (productBox.isNotEmpty &&
          bomBox.isNotEmpty &&
          userBox.isNotEmpty &&
          workCenterBox.isNotEmpty) {
        products = productBox.values
            .map((hiveP) => Product(id: hiveP.id, name: hiveP.name))
            .toList();
        users = userBox.values
            .map((hiveU) => UserModel(id: hiveU.id, name: hiveU.name))
            .toList();
        workCenters = workCenterBox.values
            .map((hiveW) => WorkCenter(id: hiveW.id, name: hiveW.name))
            .toList();
      } else {
        final fetchedProducts = await odooService.loadProducts();
        final fetchedBoms = await odooService.loadBomId(productTmplId);
        final fetchedUsers = await odooService.loadUsers();
        final fetchedWorkCenters = await odooService.loadWorkCenters();

        await productBox.clear();
        await productBox.addAll(
          fetchedProducts.map((p) => HiveProduct(id: p.id, name: p.name)),
        );
        await bomBox.clear();
        await bomBox.addAll(
          fetchedBoms.map((b) => HiveBom(id: b.id, name: b.name)),
        );
        await userBox.clear();
        await userBox.addAll(
          fetchedUsers.map((u) => HiveUserModel(id: u.id, name: u.name)),
        );
        await workCenterBox.clear();
        await workCenterBox.addAll(
          fetchedWorkCenters.map((w) => HiveWorkCenter(id: w.id, name: w.name)),
        );

        products = fetchedProducts;
        billOfMaterial = fetchedBoms;
        users = fetchedUsers;
        workCenters = fetchedWorkCenters;
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load data: $e';
      });
      if (mounted) {
        CustomSnackbar.showError(context, 'Failed to load data: $e');
      }
    }
  }

  // ────────────────────────────────────────────────────────────────
  // UI Building Helpers
  // ────────────────────────────────────────────────────────────────

  /// Returns the first BOM from the list or null if empty
  /// Used for auto-selecting BOM when product changes
  Bom? _autoSelectBom(List<Bom> boms) {
    if (boms.isEmpty) return null;
    return boms.first;
  }

  /// Builds colored status indicator pill for MO state
  Widget _buildStatusIndicator(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color getStatusColor(String status) {
      if (status.isEmpty) return Colors.grey;
      switch (status.toLowerCase()) {
        case 'draft':
          return Colors.grey;
        case 'confirmed':
          return Colors.blue;
        case 'progress':
          return Colors.orange;
        case 'to_close':
          return Colors.amber;
        case 'done':
          return Colors.green;
        case 'cancel':
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    String getStatusText(String status) {
      if (status.isEmpty) return 'Unknown';
      switch (status.toLowerCase()) {
        case 'draft':
          return 'Draft';
        case 'confirmed':
          return 'Confirmed';
        case 'progress':
          return 'In Progress';
        case 'to_close':
          return 'To Close';
        case 'done':
          return 'Done';
        case 'cancel':
          return 'Cancelled';
        default:
          return status.toUpperCase();
      }
    }

    final statusColor = getStatusColor(status);
    final statusText = getStatusText(status);
    final textColor = isDark ? Colors.white : statusColor;
    final backgroundColor = isDark
        ? Colors.white.withOpacity(0.15)
        : statusColor.withOpacity(0.10);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Manufacturing Order Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isDark ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  /// Shows confirmation dialog when user tries to leave with unsaved changes
  Future<bool> _showUnsavedChangesDialog(context) async {
    final result = await DataLossWarningDialog.show(
      context: context,
      title: 'Discard Changes?',
      message: 'You have unsaved changes. Do you want to discard them?',
      confirmText: 'Discard',
      cancelText: 'Keep Editing',
    );
    return result ?? false;
  }

  // ────────────────────────────────────────────────────────────────
  // Main Build Method
  // ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (isEditing) {
          final discard = await _showUnsavedChangesDialog(context);
          if (discard) {
            setState(() {
              isEditing = false;
            });
          }
          return false;
        }
        await widget.refreshMo?.call();
        return true;
      },
      child: BlocProvider(
        create: (context) => MoFormBloc(
          context.read<MoFormService>(),
          context.read<SettingsStorageService>(),
        )..add(LoadMoFormData(int.parse(widget.moItem['id'].toString()))),
        child: BlocConsumer<MoFormBloc, MoFormState>(
          listener: (context, state) {
            if (state.errorMessage.isNotEmpty) {
              CustomSnackbar.showError(context, state.errorMessage);
            }
          },
          builder: (context, state) {
            String currentState =
                state.moItem.isNotEmpty && state.moItem[0]['state'] != null
                ? state.moItem[0]['state'].toString().toUpperCase()
                : (moItem.isNotEmpty && moItem[0]['state'] != null
                      ? moItem[0]['state'].toString().toUpperCase()
                      : 'DRAFT');
            final moFormBloc = context.read<MoFormBloc>();
            final isDraft =
                state.moItem.isNotEmpty && state.moItem[0]['state'] == 'draft';
            final isDone =
                state.moItem.isNotEmpty && state.moItem[0]['state'] == 'done';
            final isCancelled =
                state.moItem.isNotEmpty && state.moItem[0]['state'] == 'cancel';

            return DefaultTabController(
              length: 2,
              child: Scaffold(
                backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
                  surfaceTintColor: Colors.transparent,
                  leading: IconButton(
                    icon: Icon(
                      HugeIcons.strokeRoundedArrowLeft01,
                      color: isDark ? Colors.white : Colors.black,
                      size: 28,
                    ),
                    onPressed: () async {
                      if (isEditing) {
                        final discard = await _showUnsavedChangesDialog(
                          context,
                        );
                        if (discard) {
                          setState(() {
                            isEditing = false;
                          });
                        }
                        return;
                      }
                      Navigator.of(context).pop();
                      widget.refreshMo!();
                    },
                  ),
                  title: Text(
                    isEditing
                        ? 'Edit ${widget.moItem['name'] ?? widget.moItem['name']}'
                        : (widget.moItem['name'] ??
                              widget.moItem['name'] ??
                              'Manufacturing Order'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  actions: [
                    if (!isEditing) ...[
                      if (isDraft) ...[
                        IconButton(
                          onPressed: () async {
                            setState(() {
                              isEditing = true;
                            });
                          },
                          tooltip: 'Edit Manufacture',
                          icon: Icon(
                            HugeIcons.strokeRoundedPencilEdit02,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                      if (!isCancelled) ...[
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 20,
                          ),
                          position: PopupMenuPosition.under,
                          color: isDark ? Colors.grey[900] : Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          itemBuilder: (context) {
                            List<PopupMenuEntry<String>> items = [];

                            if (isDraft) {
                              items.addAll([
                                PopupMenuItem(
                                  value: 'confirm',
                                  child: Row(
                                    children: [
                                      Icon(
                                        HugeIcons
                                            .strokeRoundedCheckmarkCircle01,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black54,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Confirm",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'cancel',
                                  child: Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedCancelCircle,
                                        size: 20,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black54,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Cancel",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]);
                            }

                            if (!isCancelled && !isDraft) {
                              if (!isDone) {
                                items.addAll([
                                  PopupMenuItem(
                                    value: 'produce_all',
                                    child: Row(
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedPackage,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Produce All",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'cancel',
                                    child: Row(
                                      children: [
                                        Icon(
                                          HugeIcons.strokeRoundedCancelCircle,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Cancel",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]);
                              }

                              if (isDone) {
                                items.add(
                                  PopupMenuItem(
                                    value: 'unbuild',
                                    child: Row(
                                      children: [
                                        Icon(
                                          HugeIcons
                                              .strokeRoundedPackageOutOfStock,
                                          size: 20,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          "Unbuild",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              items.add(
                                PopupMenuItem(
                                  value: 'scrap',
                                  child: Row(
                                    children: [
                                      Icon(
                                        HugeIcons.strokeRoundedDelete01,
                                        size: 20,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black54,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        "Scrap",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return items;
                          },
                          onSelected: (value) {
                            switch (value) {
                              case 'confirm':
                                context.read<MoFormBloc>().add(
                                  ConfirmMo(moItem),
                                );
                                ReviewService().trackSignificantEvent();
                                Future.delayed(const Duration(seconds: 3), () {
                                  ReviewService().checkAndShowRating(context);
                                });
                                break;
                              case 'cancel':
                                context.read<MoFormBloc>().add(
                                  CancelMo(moItem),
                                );
                                ReviewService().trackSignificantEvent();
                                Future.delayed(const Duration(seconds: 3), () {
                                  ReviewService().checkAndShowRating(context);
                                });
                                break;
                              case 'produce_all':
                                context.read<MoFormBloc>().add(
                                  ProduceAllMo(moItem),
                                );
                                ReviewService().trackSignificantEvent();
                                Future.delayed(const Duration(seconds: 3), () {
                                  ReviewService().checkAndShowRating(context);
                                });
                                break;
                              case 'unbuild':
                                context.read<MoFormBloc>().add(
                                  UnbuildMo(moItem),
                                );
                                ReviewService().trackSignificantEvent();
                                Future.delayed(const Duration(seconds: 3), () {
                                  ReviewService().checkAndShowRating(context);
                                });
                                break;
                              case 'scrap':
                                showDialog(
                                  context: context,
                                  builder: (context) => ScrapProductsDialog(
                                    productScrap: state.productScrap,
                                    isDraft: isDraft,
                                    onScrap:
                                        (productId, quantity, replenishQty) {
                                          moFormBloc.add(
                                            ScrapMo({
                                              'product_id': productId,
                                              'scrap_qty': quantity,
                                              'should_replenish': replenishQty,
                                              'production_id': moItem[0]['id'],
                                            }),
                                          );
                                        },
                                  ),
                                );
                                break;
                            }
                          },
                        ),
                      ],
                    ],
                  ],
                ),
                body: state.isLoading
                    ? Container(
                        width: double.infinity,
                        color: isDark
                            ? const Color(0xFF121212)
                            : const Color(0xFFF8FAFB),
                        child: const LoadingFormShimmer(itemCount: 6),
                      )
                    : NestedScrollView(
                        headerSliverBuilder: (context, innerBoxIsScrolled) => [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    8,
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[850]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withOpacity(0.18)
                                            : Colors.black.withOpacity(0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child:
                                      moItem.isNotEmpty &&
                                          moItem[0]['state'] != null
                                      ? _buildStatusIndicator(currentState)
                                      : Text(
                                          'No status available',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[600]!,
                                            fontSize: 14,
                                          ),
                                        ),
                                ),

                                if (moItem.isNotEmpty &&
                                    state.moItem.isNotEmpty)
                                  SmartTabsWidget(
                                    moItem: state.moItem,
                                    unbuildOrders: state.unbuildOrders,
                                    scrapProduct: state.scrapProduct,
                                  ),

                                Container(
                                  margin: const EdgeInsets.fromLTRB(
                                    16,
                                    5,
                                    16,
                                    8,
                                  ),
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[850]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withOpacity(0.18)
                                            : Colors.black.withOpacity(0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Manufacturing Details',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white
                                                  : AppStyle.primaryColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      if (moItem.isNotEmpty) ...[
                                        DetailRowWidget(
                                          label: 'Product',
                                          value: moItem[0]['product_id'] is List
                                              ? moItem[0]['product_id'][1]
                                              : '-',
                                          isEditable:
                                              moItem.isNotEmpty &&
                                              moItem[0]['state'] != 'done' &&
                                              moItem[0]['state'] != 'cancel',
                                          isEditing: isEditing,
                                          moItem: moItem[0],
                                          billOfMaterial: billOfMaterial,
                                          products: products,
                                          users: users,
                                          onEditTapped: () {
                                            setState(
                                              () => editingField = 'Product',
                                            );
                                          },
                                          onProductChanged: (value) {
                                            if (!mounted) return;
                                            setState(() async {
                                              updatedProduct = value?['id'];
                                              moItem[0]['product_id'] = [
                                                value?['id'],
                                                value?['name'],
                                              ];
                                              final odooService =
                                                  MoFormService();
                                              await odooService
                                                  .initializeClient();
                                              final tmplId = await odooService
                                                  .loadProductTemplateId(
                                                    updatedProduct!,
                                                  );

                                              final newBoms = await odooService
                                                  .loadBomId(tmplId);

                                              updatedBom = null;
                                              moItem[0]['bom_id'] = [
                                                false,
                                                '-',
                                              ];
                                              if (newBoms.isNotEmpty) {
                                                final autoBom = _autoSelectBom(
                                                  newBoms,
                                                );
                                                updatedBom = autoBom!.id;
                                                moveProducts = [];
                                                moveProducts = await odooService
                                                    .loadBomLine(updatedBom!);

                                                moItem[0]['bom_id'] = [
                                                  autoBom.id,
                                                  autoBom.name,
                                                ];
                                              }

                                              setState(() {
                                                billOfMaterial = newBoms;
                                              });
                                            });
                                          },
                                        ),
                                        DetailRowWidget(
                                          label: 'Quantity',
                                          value:
                                              moItem[0]['show_produce'] == true
                                              ? '${moItem[0]['qty_produced'] ?? 0} / ${moItem[0]['product_qty'] ?? 0} To Produce'
                                              : '${moItem[0]['product_qty'] ?? 0}',
                                          isEditable:
                                              moItem.isNotEmpty &&
                                              moItem[0]['state'] != 'done' &&
                                              moItem[0]['state'] != 'cancel',
                                          isEditing: isEditing,
                                          moItem: moItem[0],
                                          billOfMaterial: billOfMaterial,
                                          products: products,
                                          users: users,
                                          onEditTapped: () {
                                            setState(
                                              () => editingField = 'Quantity',
                                            );
                                          },
                                          onQtyChanged: (newValue) {
                                            setState(() {
                                              updatedQty = newValue;
                                              moItem[0]['qty_produced'] =
                                                  int.tryParse(newValue) ?? 0;
                                            });
                                          },
                                        ),
                                        DetailRowWidget(
                                          label: 'Bill of Material',
                                          value: moItem[0]['bom_id'] is List
                                              ? moItem[0]['bom_id'][1]
                                                    .toString()
                                              : '-',
                                          isEditable:
                                              moItem.isNotEmpty &&
                                              moItem[0]['state'] != 'done' &&
                                              moItem[0]['state'] != 'cancel',
                                          isEditing: isEditing,
                                          moItem: moItem[0],
                                          billOfMaterial: billOfMaterial,
                                          products: products,
                                          users: users,
                                          onEditTapped: () {
                                            setState(
                                              () => editingField =
                                                  'Bill of Material',
                                            );
                                          },
                                          onBomChanged: (value) async {
                                            setState(() {
                                              updatedBom = value?['id'];
                                              moItem[0]['bom_id'] = [
                                                value?['id'],
                                                value?['name'],
                                              ];
                                            });
                                            if (updatedBom != null) {
                                              final odooMoService =
                                                  MoListService();
                                              await odooMoService
                                                  .initializeClient();

                                              await odooMoService
                                                  .loadBomComponents(
                                                    updatedBom!,
                                                  );
                                              await odooMoService.loadBomHeader(
                                                updatedBom!,
                                              );
                                            }
                                          },
                                        ),
                                        if (enableOrderDeadline)
                                          DetailRowWidget(
                                            label: 'Scheduled Date',
                                            value: _formatDate(
                                              moItem[0]['date_start'],
                                            ),
                                            isEditable:
                                                moItem.isNotEmpty &&
                                                moItem[0]['state'] != 'done' &&
                                                moItem[0]['state'] != 'cancel',
                                            isEditing: isEditing,
                                            moItem: moItem[0],
                                            billOfMaterial: billOfMaterial,
                                            products: products,
                                            users: users,
                                            onEditTapped: () {
                                              setState(
                                                () => editingField =
                                                    'Scheduled Date',
                                              );
                                            },
                                            onScheduleDateChanged:
                                                (pickedDate) {
                                                  final normalizedDate =
                                                      DateTime(
                                                        pickedDate.year,
                                                        pickedDate.month,
                                                        pickedDate.day,
                                                        0,
                                                        0,
                                                        0,
                                                      );
                                                  setState(() {
                                                    updatedScheduleDate =
                                                        normalizedDate;
                                                    moItem[0]['date_start'] =
                                                        DateFormat(
                                                          'yyyy-MM-dd HH:mm:ss',
                                                        ).format(pickedDate);
                                                  });
                                                },
                                          ),
                                        if (enableManufacturingDeadline)
                                          DetailRowWidget(
                                            label: 'End Date',
                                            value: _formatDate(
                                              moItem[0]['date_finished'],
                                            ),
                                            isEditable:
                                                moItem.isNotEmpty &&
                                                moItem[0]['state'] != 'done' &&
                                                moItem[0]['state'] != 'cancel',
                                            isEditing: isEditing,
                                            moItem: moItem[0],
                                            billOfMaterial: billOfMaterial,
                                            products: products,
                                            users: users,
                                            onEditTapped: () {
                                              setState(
                                                () => editingField = 'End',
                                              );
                                            },
                                            onEndDateChanged: (pickedDate) {
                                              final normalizedDate = DateTime(
                                                pickedDate.year,
                                                pickedDate.month,
                                                pickedDate.day,
                                                0,
                                                0,
                                                0,
                                              );
                                              setState(() {
                                                updatedEndDate = normalizedDate;
                                                moItem[0]['date_finished'] =
                                                    DateFormat(
                                                      'yyyy-MM-dd HH:mm:ss',
                                                    ).format(pickedDate);
                                              });
                                            },
                                          ),
                                        DetailRowWidget(
                                          label: 'Component Status',
                                          value:
                                              moItem[0]['components_availability'] !=
                                                  null
                                              ? (moItem[0]['components_availability']
                                                            .toString()
                                                            .toLowerCase() ==
                                                        'available'
                                                    ? 'Available'
                                                    : 'Not Available')
                                              : '-',
                                          valueColor: _getStatusColor(
                                            moItem[0]['components_availability']
                                                    ?.toString()
                                                    .toLowerCase() ??
                                                '',
                                          ),
                                          isEditable: false,
                                          isEditing: false,
                                          moItem: moItem[0],
                                          billOfMaterial: billOfMaterial,
                                          products: products,
                                          users: users,
                                        ),
                                        DetailRowWidget(
                                          label: 'Responsible',
                                          value: moItem[0]['user_id'] is List
                                              ? moItem[0]['user_id'][1]
                                              : '-',
                                          isEditable:
                                              moItem.isNotEmpty &&
                                              moItem[0]['state'] != 'done' &&
                                              moItem[0]['state'] != 'cancel',
                                          isEditing: isEditing,
                                          moItem: moItem[0],
                                          billOfMaterial: billOfMaterial,
                                          products: products,
                                          users: users,
                                          onEditTapped: () {
                                            setState(
                                              () =>
                                                  editingField = 'Responsible',
                                            );
                                          },
                                          onUserChanged: (value) {
                                            setState(() {
                                              updatedUser = value?['id'];
                                              moItem[0]['user_id'] = [
                                                value?['id'],
                                                value?['name'],
                                              ];
                                            });
                                          },
                                        ),
                                      ] else
                                        Text(
                                          'No Manufacturing Order data available',
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[600]!,
                                            fontSize: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 5),
                              ],
                            ),
                          ),
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _SliverTabBarDelegate(
                              TabBar(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                indicator: BoxDecoration(
                                  color: isDark ? Colors.white : Colors.black,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                dividerColor: Colors.transparent,
                                labelColor: isDark
                                    ? Colors.black
                                    : Colors.white,
                                unselectedLabelColor: isDark
                                    ? Colors.white
                                    : Colors.black,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                overlayColor: MaterialStateProperty.all(
                                  Colors.transparent,
                                ),
                                indicatorSize: TabBarIndicatorSize.label,
                                tabs: [
                                  _buildCompactTab("Components", isDark),
                                  _buildCompactTab("Work Orders", isDark),
                                ],
                              ),
                              isDark,
                            ),
                          ),
                        ],
                        body: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[850]
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withOpacity(0.18)
                                            : Colors.black.withOpacity(0.06),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TabBarView(
                                      children: [
                                        ProductTableWidget(
                                          moveProducts: (updatedBom == null)
                                              ? state.moveProducts
                                              : (moveProducts != null &&
                                                    moveProducts.isNotEmpty)
                                              ? mergeWithoutDuplicates(
                                                  state.moveProducts,
                                                  moveProducts ?? [],
                                                )
                                              : state.moveProducts,
                                          isDraft:
                                              state.moItem.isNotEmpty &&
                                              state.moItem[0]['state'] ==
                                                  'draft',
                                          isDone:
                                              state.moItem.isNotEmpty &&
                                              state.moItem[0]['state'] ==
                                                  'done',
                                          isCancel:
                                              state.moItem.isNotEmpty &&
                                              state.moItem[0]['state'] ==
                                                  'cancel',
                                          products: state.products,
                                          onProductTapped: (product, index) {
                                            context.read<MoFormBloc>().add(
                                              UpdateEditingField('ProductLine'),
                                            );
                                          },
                                          onAddProductLine: () {
                                            context.read<MoFormBloc>().add(
                                              UpdateEditingField(
                                                'AddProductLine',
                                              ),
                                            );
                                          },
                                          onConsumeUpdated:
                                              (productMoveId, picked) {
                                                context.read<MoFormBloc>().add(
                                                  UpdateConsume(
                                                    productMoveId,
                                                    picked,
                                                  ),
                                                );
                                              },
                                        ),
                                        _workOrderTable(
                                          context.read<MoFormBloc>(),
                                          isDraft,
                                          isCancelled,
                                          isDone,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (isEditing) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final bool showProduce =
                                          state.moItem[0]['show_produce'] ==
                                          true;
                                      final updatedDetails = {
                                        'product_id':
                                            updatedProduct ??
                                            (state.moItem.isNotEmpty &&
                                                    state.moItem[0]['product_id']
                                                        is List
                                                ? state
                                                      .moItem[0]['product_id'][0]
                                                : null),
                                        'bom_id':
                                            updatedBom ??
                                            (state.moItem.isNotEmpty &&
                                                    state.moItem[0]['bom_id']
                                                        is List
                                                ? state.moItem[0]['bom_id'][0]
                                                : null),
                                        'user_id':
                                            updatedUser ??
                                            (state.moItem.isNotEmpty &&
                                                    state.moItem[0]['user_id']
                                                        is List
                                                ? state.moItem[0]['user_id'][0]
                                                : null),
                                        if (!showProduce)
                                          'product_qty':
                                              updatedQty ??
                                              state.moItem[0]['product_qty']
                                        else
                                          'qty_produced':
                                              updatedQty ??
                                              state.moItem[0]['qty_produced'],
                                        'date_start': _toOdooDate(
                                          updatedScheduleDate ??
                                              state.moItem[0]['date_start'],
                                        ),
                                        'date_finished': _toOdooDate(
                                          updatedEndDate ??
                                              state.moItem[0]['date_finished'],
                                        ),
                                      };
                                      context.read<MoFormBloc>().add(
                                        UpdateManufacturingDetails(
                                          updatedDetails,
                                          int.parse(moItem[0]['id'].toString()),
                                        ),
                                      );
                                      ReviewService().trackSignificantEvent();
                                      Future.delayed(const Duration(seconds: 3), () {
                                        ReviewService().checkAndShowRating(context);
                                      });
                                      await _refreshWorkOrders();
                                      final moItems = await MoFormService()
                                          .loadMo(moItem[0]['id']);
                                      setState(() {
                                        moItem = moItems;
                                        isEditing = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      foregroundColor: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: Icon(
                                      HugeIcons.strokeRoundedNoteAdd,
                                      size: 20,
                                    ),
                                    label: state.isLoading
                                        ? LoadingAnimationWidget.threeArchedCircle(
                                            color: isDark
                                                ? Colors.black
                                                : Colors.white,
                                            size: 22,
                                          )
                                        : const Text(
                                            'Save Manufacturing Order',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Converts DateTime or string to Odoo-compatible datetime string
  String? _toOdooDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      final utc = value.toUtc();
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(utc);
    }

    return value.toString();
  }

  /// Merges two lists of StockMove removing duplicates by productId
  List<StockMove> mergeWithoutDuplicates(
    List<StockMove> oldList,
    List<StockMove> newList,
  ) {
    final seen = <dynamic>{};
    final merged = [...oldList, ...newList];
    return merged.where((m) => seen.add(m.productId)).toList();
  }

  /// Helper to create compact, styled tab buttons
  Widget _buildCompactTab(String text, bool isDark) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.3)
                : Colors.black.withOpacity(0.2),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Work Order Timer & Action Handlers
  // ────────────────────────────────────────────────────────────────

  /// Shows dialog to create a new work order
  void _showAddWorkOrderDialog(BuildContext parentContext, bloc) {
    TextEditingController expectedDurationController = TextEditingController(
      text: "00:00",
    );
    TextEditingController realDurationController = TextEditingController(
      text: "00:00",
    );
    String operation = '';
    int? selectedWorkCenter;
    String expectedDuration = "00:00";
    String realDuration = "00:00";
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: parentContext,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Text(
                    'Add Work Order',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                width: MediaQuery.of(context).size.width * 0.95,
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SingleChildScrollView(
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (errorMessage != '') ...[
                                Text(
                                  errorMessage,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Operation",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      hintText: "Operation",
                                      hintStyle: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black54,
                                      ),
                                      prefixIcon: Icon(
                                        HugeIcons.strokeRoundedWork,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Operation is required'
                                        : null,
                                    onChanged: (value) {
                                      operation = value;
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Work Center",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  DropdownSearch<Map<String, dynamic>>(
                                    popupProps: PopupProps.menu(
                                      showSearchBox: true,
                                      searchFieldProps: TextFieldProps(
                                        decoration: InputDecoration(
                                          labelText: "Search Work Center",
                                          labelStyle: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          prefixIcon: Icon(Icons.search),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    items: workCenters
                                        .map((p) => p.toJson())
                                        .toList(),
                                    itemAsString: (item) => item?['name'] ?? '',
                                    onChanged: (value) {
                                      selectedWorkCenter = value?['id'];
                                    },
                                    dropdownDecoratorProps: DropDownDecoratorProps(
                                      dropdownSearchDecoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                        hintText: "Select Work Center",
                                        hintStyle: TextStyle(
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black54,
                                        ),
                                        prefixIcon: Icon(
                                          HugeIcons.strokeRoundedShippingCenter,
                                          color: isDark
                                              ? Colors.grey[400]
                                              : Colors.grey[500],
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: isDark
                                                ? Colors.white
                                                : AppStyle.primaryColor,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    validator: (value) => value == null
                                        ? 'Please select a Work Center'
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Product: ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: moItem[0]['product_id'][1],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Quantity: ',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                      ),
                                      TextSpan(
                                        text: moItem[0]['product_qty']
                                            .toString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.normal,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Expected Duration",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    controller: expectedDurationController,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      prefixIcon: Icon(
                                        HugeIcons.strokeRoundedTimer02,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.datetime,
                                    onChanged: (value) =>
                                        expectedDuration = value,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Real Duration",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white60
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  TextFormField(
                                    controller: realDurationController,
                                    decoration: InputDecoration(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                      prefixIcon: Icon(
                                        HugeIcons.strokeRoundedTimer02,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[500],
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    keyboardType: TextInputType.datetime,
                                    onChanged: (value) => realDuration = value,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Status:  ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Ready',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
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
                    if (isWorkOrder)
                      Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: isDark ? Colors.white : AppStyle.primaryColor,
                          size: 50,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.white,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          label: Text(
                            'Add',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            setDialogState(() {
                              isWorkOrder = true;
                            });
                            if (formKey.currentState?.validate() ?? false) {
                              final expectedDurationHours =
                                  parseDurationToHours(expectedDuration);
                              final realDurationHours = parseDurationToHours(
                                realDuration,
                              );

                              final updatedDetails = {
                                'name': operation,
                                'workcenter_id': selectedWorkCenter,
                                'duration_expected': expectedDurationHours,
                                'duration': realDurationHours,
                                'production_id': widget.moItem['id'],
                                'product_uom_id':
                                    moItem[0]['product_uom_id'][0],
                              };

                              final moFormService = MoFormService();
                              await moFormService.initializeClient();
                              final success = await moFormService
                                  .updateWorkOrderDetails(updatedDetails);
                              if (success) {
                                await _loadOnlineData();
                                setDialogState(() {
                                  isWorkOrder = false;
                                });
                                Navigator.of(context).pop();
                              } else {
                                setDialogState(() {
                                  errorMessage =
                                      "You cannot create cyclic dependency";
                                });
                                setDialogState(() {
                                  isWorkOrder = false;
                                });
                                Navigator.of(context).pop();
                                _showAddWorkOrderDialog(context, bloc);
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Parses duration string (HH:MM or MM:SS) to hours (decimal)
  double parseDurationToHours(String durationString) {
    try {
      final parts = durationString.split(':');
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      return hours + (minutes / 60);
    } catch (e) {
      return 0.0;
    }
  }

  /// Formats Duration object to human-readable string (HH:MM:SS or MM:SS)
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '00:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Builds the work order list with start/pause/done controls
  Widget _workOrderTable(MoFormBloc bloc, isDraft, isCancelled, isDone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        if (moItem != null &&
            moItem.isNotEmpty &&
            moItem[0]['state'] != 'done' &&
            moItem[0]['state'] != 'cancel') ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      errorMessage = '';
                    });
                    _showAddWorkOrderDialog(context, bloc);
                  },
                  label: Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFF2A2A2A)
                        : Color(0xFFC03355),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: workOrders.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.engineering_outlined,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Work Orders added yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600]!,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add work orders to define the manufacturing process',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500]!,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: workOrders.length,
                  itemBuilder: (context, index) {
                    final workOrder = workOrders[index];
                    final operationName = workOrder.operation.toString();
                    final workCenter = workOrder.workCenterId?[1] ?? '-';
                    final expectedDuration = workOrder.formattedExpectedDuration
                        .toString();
                    final isRunning = _timerService.isWorkOrderRunning(
                      workOrder.id,
                    );
                    String realDuration;

                    if (isRunning) {
                      final totalDuration = _timerService
                          .getDurationForWorkOrder(workOrder.id);
                      final baseDuration = _timerService.getBaseDuration(
                        workOrder.id,
                      );
                      realDuration = _formatDuration(totalDuration);
                    } else {
                      realDuration = workOrder.formattedDuration;
                    }
                    final status = workOrder.state ?? '-';

                    String statusText = '';
                    Color statusColor = Colors.grey;

                    switch (status.toLowerCase()) {
                      case 'pending':
                        statusText = 'Waiting for another WO';
                        statusColor = Colors.teal;
                        break;
                      case 'waiting':
                        statusText = 'Waiting for Components';
                        statusColor = Colors.amber;
                        break;
                      case 'ready':
                        statusText = 'Ready';
                        statusColor = Colors.blue;
                        break;
                      case 'progress':
                        statusText = 'In Progress';
                        statusColor = Colors.orange;
                        break;
                      case 'done':
                        statusText = 'Done';
                        statusColor = Colors.green;
                        break;
                      case 'cancel':
                        statusText = 'Cancelled';
                        statusColor = Colors.red;
                        break;
                      default:
                        statusText = status.toUpperCase();
                        statusColor = Colors.grey;
                    }

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Operation: $operationName",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : AppStyle.primaryColor,
                                      fontSize: 16,
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Work Center: $workCenter",
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Expected Duration: $expectedDuration",
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Real Duration:",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: isRealUpdate[index]
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            backgroundColor: Colors.transparent,
                                            color: isDark
                                                ? Colors.white
                                                : AppStyle.primaryColor,
                                          ),
                                        )
                                      : Text(
                                          realDuration,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isDraft && !isCancelled && !isDone) ...[
                                  if (status.toLowerCase() != 'done') ...[
                                    if (!isRunning) ...[
                                      ElevatedButton(
                                        onPressed: () async {
                                          setState(() {
                                            isStartLoading[index] = true;
                                          });
                                          await _handleStartWorkOrder(
                                            workOrder,
                                          );
                                          setState(() {
                                            isStartLoading[index] = false;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? Colors.white
                                              : Color(0xFFC03355),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: isStartLoading[index]
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      color: isDark
                                                          ? Colors.grey[600]
                                                          : Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                'Start',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.black
                                                      : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ] else ...[
                                      ElevatedButton(
                                        onPressed: () async {
                                          setState(() {
                                            isPauseLoading[index] = true;
                                          });
                                          await _handlePauseWorkOrder(
                                            workOrder,
                                          );
                                          setState(() {
                                            isPauseLoading[index] = false;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white
                                                : Color(0xFFC03355),
                                            width: 2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        child: isPauseLoading[index]
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      color: isDark
                                                          ? Colors.white
                                                          : AppStyle
                                                                .primaryColor,
                                                    ),
                                              )
                                            : Text(
                                                'Pause',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : Color(0xFFC03355),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () async {
                                          setState(() {
                                            isDoneLoading[index] = true;
                                          });
                                          await _handleStopWorkOrder(workOrder);
                                          setState(() {
                                            isDoneLoading[index] = false;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? Colors.white
                                              : Color(0xFFC03355),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: isDoneLoading[index]
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      backgroundColor:
                                                          Colors.transparent,
                                                      color: isDark
                                                          ? Colors.grey[600]
                                                          : Colors.white,
                                                    ),
                                              )
                                            : Text(
                                                'Done',
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.black
                                                      : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ],
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Parses formatted duration string back to Duration object
  Duration _parseDurationFromBackend(String formattedDuration) {
    try {
      if (formattedDuration.contains(':')) {
        final parts = formattedDuration.split(':');

        if (parts.length == 3) {
          final hours = int.parse(parts[0]);
          final minutes = int.parse(parts[1]);
          final seconds = int.parse(parts[2]);
          return Duration(hours: hours, minutes: minutes, seconds: seconds);
        } else if (parts.length == 2) {
          final minutes = int.parse(parts[0]);
          final seconds = int.parse(parts[1]);
          return Duration(minutes: minutes, seconds: seconds);
        }
      } else {
        final number = double.tryParse(formattedDuration);
        if (number != null) {
          return Duration(minutes: number.round());
        }
      }
      return Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
  }

  /// Starts timer + calls backend to mark work order as in progress
  Future<void> _handleStartWorkOrder(MoWorkOrder workOrder) async {
    try {
      final odooMoService = MoFormService();
      await odooMoService.initializeClient();
      final moId = int.parse(widget.moItem['id'].toString());
      final backendDuration = _parseDurationFromBackend(
        workOrder.formattedDuration,
      );

      final success = await odooMoService.startWorkOrder(moId, workOrder.id);
      if (success) {
        await _timerService.startWorkOrder(
          workOrder.id,
          baseDuration: backendDuration,
        );

        await _refreshWorkOrders();
      } else {
        if (mounted) {
          CustomSnackbar.showError(context, 'Failed to start work order');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Pauses timer + calls backend pause endpoint
  Future<void> _handlePauseWorkOrder(MoWorkOrder workOrder) async {
    try {
      final odooMoService = MoFormService();
      await odooMoService.initializeClient();
      final moId = int.parse(widget.moItem['id'].toString());

      odooMoService.pauseWorkOrder(moId, workOrder.id);

      _timerService.stopWorkOrder(workOrder.id);
      setState(() {
        isRealUpdate = List.filled(workOrders.length, true);
      });
      await _refreshWorkOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Stops timer + marks work order as done in backend
  Future<void> _handleStopWorkOrder(MoWorkOrder workOrder) async {
    try {
      final odooMoService = MoFormService();
      await odooMoService.initializeClient();
      final moId = int.parse(widget.moItem['id'].toString());

      odooMoService.stopWorkOrder(moId, workOrder.id);

      _timerService.stopWorkOrder(workOrder.id);
      setState(() {
        isRealUpdate = List.filled(workOrders.length, true);
      });
      await _refreshWorkOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Formats date string from Odoo format to user-friendly local format
  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    final rawDate = dateString;
    DateTime parsedDate = DateTime.parse("${rawDate}Z").toLocal();
    String formattedDate = DateFormat('MM/dd/yyyy HH:mm:ss').format(parsedDate);

    return formattedDate;
  }

  /// Color helper for component availability status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case "not available":
        return Colors.red;
      case "available":
        return Colors.green;
      default:
        return Colors.black54;
    }
  }
}

/// Custom SliverPersistentHeaderDelegate for pinned tab bar
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final bool _isDark;

  _SliverTabBarDelegate(this._tabBar, this._isDark);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _tabBar,
    );
  }

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => false;
}
