import 'dart:async';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../WorkOrders/model/work_order.dart';
import '../../../../globals.dart';
import 'package:hive_ce/hive.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../shared/widgets/snackbar.dart';
import '../../MoForm/models/bom.dart';
import '../../MoForm/models/product.dart';
import '../../MoForm/models/stock_move.dart';
import '../../MoForm/models/user_model.dart';
import '../../MoForm/models/work_center.dart';
import '../../MoForm/service/mo_form_service.dart';
import '../../MoForm/widgets/mo_form/detail_row_widget.dart';
import '../bloc/create_mo_bloc.dart';
import '../bloc/create_mo_event.dart';
import '../bloc/create_mo_state.dart';
import '../model/bom_model.dart';
import '../service/hive/models.dart';
import '../service/mo_list_service.dart';

/// A screen for creating a new Manufacturing Order (MO) in a Flutter application.
/// Allows selection of product, BOM, quantity, dates, responsible person,
/// manual addition of components and work orders, and final submission to Odoo.
class CreateMOViewPage extends StatefulWidget {
  const CreateMOViewPage({super.key});

  @override
  State<CreateMOViewPage> createState() => _CreateMOViewPageState();
}

/// State management for [CreateMOViewPage].
/// Handles form state, local caching with Hive, Odoo data fetching,
/// BOM auto-selection, component/work order management, and MO creation.
class _CreateMOViewPageState extends State<CreateMOViewPage> {
  final TextEditingController _productQtyController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int? selectedProduct;
  int? selectedComponents;
  int? selectedWorkCenter;
  int? selectedBom;
  int? selectedUser;
  DateTime? scheduledDate;
  DateTime? endDate;
  String? errorMessage;
  String errorPopupMessage = '';
  String? selectedComponentName;
  bool isFormValid = false;
  String operation = '';
  String expectedDuration = '';
  String workCenter = '';

  List<Product> products = [];
  List<Bom> billOfMaterial = [];
  List<UserModel> users = [];
  List<StockMove> moveProducts = [];
  List<WorkCenter> workCenters = [];
  List<WorkOrder> workOrders = [];
  List<BomLineModel> bomComponents = [];
  List<BomLineModel> manualComponents = [];

  late TextEditingController _toConsumeController;
  late TextEditingController _operationController;
  late TextEditingController _expectedDurationController;
  String toConsume = "";
  bool _isLoading = true;

  // Controllers, form keys, selection variables, lists...

  /// Initializes controllers and triggers initial data loading after first frame.
  @override
  void initState() {
    super.initState();
    _toConsumeController = TextEditingController(text: '1.0');
    _operationController = TextEditingController();
    _expectedDurationController = TextEditingController(text: '00:00');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  /// Cleans up text controllers when the widget is removed from the tree.
  @override
  void dispose() {
    _toConsumeController.dispose();
    _operationController.dispose();
    _expectedDurationController.dispose();
    _productQtyController.dispose();
    super.dispose();
  }

  /// Loads products, BOMs, users, and work centers either from Hive cache
  /// or from Odoo server (and then caches them).
  ///
  /// Updates UI loading state and populates corresponding lists.
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);

    try {
      final productBox = await Hive.openBox<HiveProduct>('products');
      final bomBox = await Hive.openBox<HiveBom>('bom');
      final userBox = await Hive.openBox<HiveUserModel>('users');
      final workCenterBox = await Hive.openBox<HiveWorkCenter>('workCenters');

      if (productBox.isNotEmpty &&
          bomBox.isNotEmpty &&
          userBox.isNotEmpty &&
          workCenterBox.isNotEmpty) {
        products = productBox.values
            .map((hiveP) => Product(id: hiveP.id, name: hiveP.name))
            .toList();

        billOfMaterial = bomBox.values
            .map((hiveB) => Bom(id: hiveB.id, name: hiveB.name))
            .toList();

        users = userBox.values
            .map((hiveU) => UserModel(id: hiveU.id, name: hiveU.name))
            .toList();

        workCenters = workCenterBox.values
            .map((hiveW) => WorkCenter(id: hiveW.id, name: hiveW.name))
            .toList();
      } else {
        final odooService = MoFormService();
        await odooService.initializeClient();

        final fetchedProducts = await odooService.loadProducts();
        final fetchedBoms = await odooService.loadBom();
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Validates the main form and updates [isFormValid] flag.
  void _validateForm() {
    setState(() {
      isFormValid = _formKey.currentState?.validate() ?? false;
    });
  }

  /// Builds the product selection row with auto BOM loading logic.
  ///
  /// When a product is selected, attempts to load associated BOMs,
  /// auto-selects the first one, and populates components & work orders.
  Widget _buildProductSelection() {
    final selected = selectedProduct != null
        ? products.firstWhere(
            (p) => p.id == selectedProduct,
            orElse: () => Product(id: selectedProduct!, name: 'Unknown'),
          )
        : null;

    final moItemProduct = selected != null
        ? {
            'product_id': [selected.id, selected.name],
          }
        : {'product_id': null};
    return DetailRowWidget(
      label: 'Product',
      value: selected != null ? selected.name : 'Select a product',

      isEditable: true,
      isEditing: true,
      moItem: moItemProduct,

      billOfMaterial: billOfMaterial,
      products: products,
      users: users,
      onEditTapped: () {},
      onProductChanged: (value) async {
        setState(() {
          selectedProduct = value?['id'];
        });
        final odooService = MoFormService();
        await odooService.initializeClient();
        final tmplId = await odooService.loadProductTemplateId(
          selectedProduct!,
        );

        final newBoms = await odooService.loadBomId(tmplId);
        selectedBom = null;
        bomComponents = [];
        workOrders = [];
        if (newBoms.isNotEmpty) {
          final autoBom = _autoSelectBom(newBoms);
          selectedBom = autoBom!.id;

          final odooMoService = MoListService();
          await odooMoService.initializeClient();

          final bomHeader = await odooMoService.loadBomHeader(autoBom.id);

          final bomComponentsList = await odooMoService.loadBomComponents(
            autoBom.id,
          );

          final bomWorkOrders = await odooMoService.loadWorkOrdersByBom(
            autoBom.id,
          );

          setState(() {
            selectedProduct = bomHeader?['variant_id'];
            bomComponents = bomComponentsList;
            workOrders = bomWorkOrders;
          });
        }
        _validateForm();
      },
    );
  }

  /// Selects the first available BOM from the list (simple auto-select strategy).
  ///
  /// Returns `null` if the list is empty.
  Bom? _autoSelectBom(List<Bom> boms) {
    if (boms.isEmpty) return null;
    return boms.first;
  }

  /// Builds the quantity input row for the manufactured product.
  Widget _buildQuantityField() {
    return DetailRowWidget(
      label: 'Quantity',
      value: _productQtyController.text.isEmpty
          ? '0'
          : _productQtyController.text,
      isEditable: true,
      isEditing: true,
      moItem: {'product_qty': 0, 'qty_produced': 0},
      billOfMaterial: billOfMaterial,
      products: products,
      users: users,
      onEditTapped: () {},
      onQtyChanged: (newValue) {
        setState(() {
          _productQtyController.text = newValue;
        });
        _validateForm();
      },
    );
  }

  /// Builds the Bill of Materials selection row.
  ///
  /// When BOM changes → reloads components and work orders.
  Widget _buildBOMSelection() {
    final selectedB = selectedBom != null
        ? billOfMaterial.firstWhere(
            (b) => b.id == selectedBom,
            orElse: () => Bom(id: selectedBom!, name: 'Unknown'),
          )
        : null;

    final moItemBom = selectedB != null
        ? {
            'bom_id': [selectedB.id, selectedB.name],
          }
        : {'bom_id': null};

    return DetailRowWidget(
      label: 'Bill of Material',
      value: selectedBom != null ? selectedB!.name : 'Select BOM',
      isEditable: true,
      isEditing: true,
      moItem: moItemBom,

      billOfMaterial: billOfMaterial,
      products: products,
      users: users,
      onEditTapped: () {},
      onBomChanged: (value) async {
        setState(() {
          selectedBom = value?['id'];
        });
        if (selectedBom != null) {
          final odooMoService = MoListService();
          await odooMoService.initializeClient();

          final components = await odooMoService.loadBomComponents(
            selectedBom!,
          );
          final componentProduct = await odooMoService.loadBomHeader(
            selectedBom!,
          );
          final bomWorkOrders = await odooMoService.loadWorkOrdersByBom(
            selectedBom!,
          );
          setState(() {
            bomComponents = components;
            selectedProduct = componentProduct?['variant_id'];
            workOrders = bomWorkOrders;
          });
        }
        _validateForm();
      },
    );
  }

  /// Builds the scheduled start date picker row.
  Widget _buildScheduledDate() {
    return DetailRowWidget(
      label: 'Scheduled Date',
      value: scheduledDate != null
          ? DateFormat('dd/MM/yyyy').format(scheduledDate!)
          : 'Select date',
      isEditable: true,
      isEditing: true,
      moItem: {'date_start': null},
      billOfMaterial: billOfMaterial,
      products: products,
      users: users,
      onEditTapped: () {},
      onScheduleDateChanged: (pickedDate) {
        setState(() {
          scheduledDate = pickedDate;
        });
      },
    );
  }

  /// Builds the expected end date picker row.
  Widget _buildEndDate() {
    return DetailRowWidget(
      label: 'End Date',
      value: endDate != null
          ? DateFormat('dd/MM/yyyy').format(endDate!)
          : 'Select date',
      isEditable: true,
      isEditing: true,
      moItem: {'date_finished': null},
      billOfMaterial: billOfMaterial,
      products: products,
      users: users,
      onEditTapped: () {},
      onEndDateChanged: (pickedDate) {
        setState(() {
          endDate = pickedDate;
        });
      },
    );
  }

  /// Builds the responsible user selection row.
  Widget _buildResponsibleSelection() {
    return DetailRowWidget(
      label: 'Responsible',
      value: selectedUser != null
          ? users.firstWhere((u) => u.id == selectedUser).name
          : 'Select responsible',
      isEditable: true,
      isEditing: true,
      moItem: {'user_id': null},
      billOfMaterial: billOfMaterial,
      products: products,
      users: users,
      onEditTapped: () {},
      onUserChanged: (value) {
        setState(() {
          selectedUser = value?['id'];
        });
      },
    );
  }

  /// Main build method — constructs the full screen with:
  ///   - AppBar
  ///   - Form validation
  ///   - Loading overlay
  ///   - Manufacturing details card
  ///   - Components / Work Orders tabs
  ///   - Create button with BLoC integration
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingAnimationWidget.fourRotatingDots(
                color: isDark ? Colors.white : AppStyle.primaryColor,
                size: 50,
              ),
              const SizedBox(height: 20),
              Text(
                "Loading data...",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return RepositoryProvider(
      create: (_) => MoListService()..initializeClient(),
      child: BlocProvider(
        create: (context) => CreateMOBloC(context.read<MoListService>()),
        child: BlocConsumer<CreateMOBloC, CreateMOState>(
          listener: (context, state) {
            if (state.errorMessage.isNotEmpty) {
              CustomSnackbar.showError(context, state.errorMessage);
            }

            if (state.isSuccess) {
              Navigator.of(context).pop(true);
            }
          },
          builder: (context, state) {
            if (state.isLoading && products.isEmpty) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return Form(
              key: _formKey,
              onChanged: _validateForm,
              child: Scaffold(
                backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
                appBar: AppBar(
                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: Icon(
                        HugeIcons.strokeRoundedArrowLeft01,
                        color: isDark ? Colors.white : Colors.black,
                        size: 24,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  title: Text(
                    'New MO',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                      fontSize: 20,
                    ),
                  ),
                  automaticallyImplyLeading: false,
                ),
                body: Stack(
                  children: [
                    Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[50],
                      child: DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
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
                                                : Colors.black.withOpacity(
                                                    0.06,
                                                  ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'DRAFT',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    if (errorMessage != null)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey[850]
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: isDark
                                                  ? Colors.black.withOpacity(
                                                      0.18,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.06,
                                                    ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: Colors.red,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  errorMessage!,
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                    Container(
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
                                                : Colors.black.withOpacity(
                                                    0.06,
                                                  ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    const BorderRadius.only(
                                                      topLeft: Radius.circular(
                                                        16,
                                                      ),
                                                      topRight: Radius.circular(
                                                        16,
                                                      ),
                                                    ),
                                              ),
                                              child: Text(
                                                'Manufacturing Details',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.grey[900],
                                                  letterSpacing: -0.3,
                                                ),
                                              ),
                                            ),
                                            Divider(
                                              height: 1,
                                              color: isDark
                                                  ? Colors.grey[700]
                                                  : Colors.grey[200],
                                            ),
                                            _buildProductSelection(),
                                            _buildQuantityField(),
                                            _buildBOMSelection(),
                                            _buildScheduledDate(),
                                            _buildEndDate(),
                                            _buildResponsibleSelection(),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Container(
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
                                                : Colors.black.withOpacity(
                                                    0.06,
                                                  ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(24.0),
                                        child: Column(
                                          children: [
                                            TabBar(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 3,
                                                  ),
                                              indicator: BoxDecoration(
                                                color: Colors.black,
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                              ),
                                              dividerColor: Colors.transparent,
                                              labelColor: Colors.white,
                                              unselectedLabelColor: isDark
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              indicatorPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 6,
                                                  ),
                                              overlayColor:
                                                  MaterialStateProperty.all(
                                                    Colors.transparent,
                                                  ),
                                              indicatorSize:
                                                  TabBarIndicatorSize.label,
                                              tabs: [
                                                _buildCompactTab(
                                                  "Components",
                                                  isDark,
                                                ),
                                                _buildCompactTab(
                                                  "Work Orders",
                                                  isDark,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            SizedBox(
                                              height: 300,
                                              child: TabBarView(
                                                children: [
                                                  _productTable(),
                                                  _workOrderTable(),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          final allComponents = [
                                            ...bomComponents,
                                            ...manualComponents,
                                          ];
                                          final moData = {
                                            'moCreate': {
                                              'product_id': selectedProduct,
                                              'product_qty':
                                                  int.tryParse(
                                                    _productQtyController.text,
                                                  ) ??
                                                  1,
                                              'bom_id': selectedBom,
                                              'user_id': selectedUser,
                                              'date_start':
                                                  DateFormat(
                                                    'yyyy-MM-dd',
                                                  ).format(
                                                    scheduledDate ??
                                                        DateTime.now(),
                                                  ),
                                              'date_finished':
                                                  DateFormat(
                                                    'yyyy-MM-dd',
                                                  ).format(
                                                    endDate ?? DateTime.now(),
                                                  ),
                                            },
                                            'productData': allComponents.map((
                                              comp,
                                            ) {
                                              return {
                                                'product_id': comp.productId,
                                                'product_uom_qty':
                                                    comp.toConsume,
                                              };
                                            }).toList(),
                                            'workOrderData': workOrders.map((
                                              wo,
                                            ) {
                                              return {
                                                'name': wo.operation,
                                                'workcenter_id':
                                                    wo.workCenterId,
                                                'duration_expected':
                                                    wo.expectedDuration,
                                                'product_uom_id': 1,
                                              };
                                            }).toList(),
                                          };
                                          context.read<CreateMOBloC>().add(
                                            CreateManufacturingOrder(moData),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDark
                                              ? Colors.white
                                              : AppStyle.primaryColor,
                                          foregroundColor: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                          elevation: 0,
                                          shadowColor: Colors.transparent,
                                          disabledBackgroundColor: isDark
                                              ? Colors.grey[700]!
                                              : Colors.grey[400]!,
                                        ),
                                        icon: Icon(
                                          HugeIcons.strokeRoundedNoteAdd,
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          size: 20,
                                        ),
                                        label: state.isLoading
                                            ? LoadingAnimationWidget.threeArchedCircle(
                                                color: isDark
                                                    ? Colors.black
                                                    : Colors.white,
                                                size: 22,
                                              )
                                            : Text(
                                                "Create Manufacturing Order",
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.black
                                                      : Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (state.isLoading) ...[
                      Positioned.fill(
                        child: Center(
                          child: LoadingAnimationWidget.fourRotatingDots(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            size: 50,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Helper method that creates a compact, bordered tab label.
  Widget _buildCompactTab(String text, bool isDark) {
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

  /// Opens a dialog to manually add a new work order (operation + work center + duration).
  void _showAddWorkOrderDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Add Work Order",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.25,
            width: MediaQuery.of(context).size.width * 0.95,
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      if (errorPopupMessage != '')
                        Text(
                          errorPopupMessage,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Operation",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _operationController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              hintText: "Operation",
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.normal,
                                color: isDark ? Colors.white54 : Colors.black54,
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
                            onChanged: (val) {
                              setState(() {
                                operation = val;
                              });
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Work Center",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          DropdownSearch<Map<String, dynamic>>(
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: "Search Work Center",
                                  hintStyle: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            items: workCenters.map((p) => p.toJson()).toList(),
                            itemAsString: (item) => item?['name'] ?? '',
                            onChanged: (value) {
                              selectedWorkCenter = value?['id'];
                              workCenter = value?['name'];
                            },
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
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
                            ),
                            validator: (value) => value == null
                                ? 'Please select a Work Center'
                                : null,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Expected Duration",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _expectedDurationController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
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
                            onChanged: (val) {
                              setState(() {
                                expectedDuration = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                      side: BorderSide(
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppStyle.primaryColor,
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
                      if (_operationController.text.isEmpty) {
                        setState(() {
                          errorPopupMessage = "Please add operation";
                        });
                        Navigator.of(context).pop();
                        _showAddWorkOrderDialog();
                      } else if (selectedWorkCenter == null) {
                        setState(() {
                          errorPopupMessage = "Please choose work center";
                        });
                        Navigator.of(context).pop();
                        _showAddWorkOrderDialog();
                      } else {
                        setState(() {
                          errorPopupMessage = "";
                        });
                        final newOrder = WorkOrder(
                          id: DateTime.now().millisecondsSinceEpoch,
                          operation: operation,
                          workCenter: workCenter,
                          expectedDuration:
                              double.tryParse(expectedDuration) ?? 0.0,
                          realDuration: 0.0,
                          status: "ready",
                          product: '',
                          quantity: 0,
                          workCenterId: selectedWorkCenter!,
                        );
                        setState(() {
                          workOrders.add(newOrder);
                        });
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Opens a dialog to manually add an extra component (product + to-consume quantity).
  void _showAddProductDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Add Components",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.20,
            width: MediaQuery.of(context).size.width * 0.95,
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      if (errorPopupMessage != '')
                        Text(
                          errorPopupMessage,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Product",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          DropdownSearch<Map<String, dynamic>>(
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  labelText: "Search Products",
                                  hintStyle: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  prefixIcon: Icon(Icons.search),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            items: products.map((p) => p.toJson()).toList(),
                            itemAsString: (item) => item?['name'] ?? '',
                            onChanged: (value) {
                              selectedComponents = value?['id'];
                              selectedComponentName = value?['name'] ?? '';
                            },
                            dropdownDecoratorProps: DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                hintText: "Select Product",
                                hintStyle: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
                                ),
                                prefixIcon: Icon(
                                  Icons.inventory_2,
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
                            ),
                            validator: (value) => value == null
                                ? 'Please select a Product'
                                : null,
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "To Consume QTY",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _toConsumeController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              hintText: 'Add Consume QTY',
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white60 : Colors.black87,
                              ),
                              prefixIcon: Icon(
                                Icons.format_list_numbered,
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
                            onChanged: (val) {
                              setState(() {
                                toConsume = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                      side: BorderSide(
                        color: isDark ? Colors.white : AppStyle.primaryColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppStyle.primaryColor,
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: () {
                      if (selectedComponents == null) {
                        setState(() {
                          errorPopupMessage = "Please choose product";
                        });
                        Navigator.of(context).pop();
                        _showAddProductDialog();
                      }
                      if (selectedComponents != null &&
                          _toConsumeController.text.isNotEmpty) {
                        setState(() {
                          errorPopupMessage = '';
                          manualComponents.add(
                            BomLineModel(
                              productId: selectedComponents!,
                              productName: selectedComponentName!,
                              toConsume:
                                  double.tryParse(_toConsumeController.text) ??
                                  0.0,
                            ),
                          );
                        });
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Renders the "Components" tab content:
  ///   - List of BOM lines + manually added components
  ///   - "+ Add a line" button that opens component dialog
  Widget _productTable() {
    final allComponents = [...bomComponents, ...manualComponents];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    "Product",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "To Consume",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          ...allComponents.map((comp) {
            final productName = products
                .firstWhere(
                  (p) => p.id == comp.productId,
                  orElse: () => Product(id: comp.productId, name: "Unknown"),
                )
                .name;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  Expanded(flex: 5, child: Text(productName)),
                  Expanded(flex: 2, child: Text(comp.toConsume.toString())),
                ],
              ),
            );
          }).toList(),

          SizedBox(height: 10),

          GestureDetector(
            onTap: () {
              setState(() {
                errorPopupMessage = "";
              });
              _showAddProductDialog();
            },
            child: Text(
              "+ Add a line",
              style: TextStyle(
                color: isDark ? Colors.white : Color(0xFFC03355),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Renders the "Work Orders" tab content:
  ///   - "Add Work Order" button
  ///   - List of work orders (or empty state)
  Widget _workOrderTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  errorPopupMessage = "";
                });
                _showAddWorkOrderDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200],
                foregroundColor: isDark ? Colors.white : Colors.grey[800],
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    HugeIcons.strokeRoundedPackageAdd,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Add Work Order',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: workOrders.isEmpty
              ? Center(
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap "Add Work Order" to get started',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: workOrders.length,
                  itemBuilder: (context, index) {
                    final order = workOrders[index];

                    Color statusColor = switch (order.status.toLowerCase()) {
                      'ready' => Colors.blue,
                      'done' => Colors.green,
                      _ => Colors.grey,
                    };

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "Operation: ${order.operation}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text("Work Center: ${order.workCenter}"),
                            const SizedBox(height: 4),
                            Text(
                              "Expected Duration: ${order.expectedDuration}",
                            ),
                            const SizedBox(height: 4),
                            Text("Real Duration: ${order.realDuration}"),
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
}
