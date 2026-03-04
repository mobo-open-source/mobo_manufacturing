import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import '../../Rating/review_service.dart';
import '../../globals.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../../MO/widgets/shimmer_form_loading.dart';
import '../../shared/widgets/snackbar.dart';
import '../model/scrap.dart';
import '../service/scrap_service.dart';

/// Displays detailed information about a Scrap record.
///
/// Features:
/// • View scrap details (Product, MO, Source, Company, Date, Quantity)
/// • Edit scrap details (if state != done)
/// • Validate scrap
/// • Handle insufficient quantity confirmation
/// • Supports dark/light theme UI
///
/// Parameters:
/// • [scrap] → Scrap item basic info passed from list
/// • [refreshScrap] → Callback to refresh parent scrap list
class ScrapDetailPage extends StatefulWidget {
  final ScrapItem scrap;

  /// Callback function to refresh scrap list after update/validation.
  final Future<void> Function() refreshScrap;

  const ScrapDetailPage({
    super.key,
    required this.scrap,
    required this.refreshScrap,
  });

  @override
  State<ScrapDetailPage> createState() => _ScrapDetailPageState();
}

class _ScrapDetailPageState extends State<ScrapDetailPage> {
  /// API response storage lists
  List<Map<String, dynamic>> scrapItem = [];
  List<Map<String, dynamic>> productItem = [];
  List<Map<String, dynamic>> moItem = [];
  List<Map<String, dynamic>> companyItem = [];

  /// Controllers for form fields
  TextEditingController productController = TextEditingController();
  TextEditingController moController = TextEditingController();
  TextEditingController sourceController = TextEditingController();
  TextEditingController dateController = TextEditingController();
  TextEditingController companyController = TextEditingController();
  TextEditingController quantityController = TextEditingController();

  /// UI state flags
  bool isEditing = false;
  bool isLoading = true;

  /// Selected dropdown values
  int? selectedProductId;
  String? selectedProductName;
  Map<String, dynamic>? selectedProduct;

  int? selectedMOId;
  String? selectedMOName;
  Map<String, dynamic>? selectedMO;

  int? selectedCompanyId;
  String? selectedCompanyName;
  Map<String, dynamic>? selectedCompany;

  /// Selected date value
  DateTime? dateTime;

  /// Initializes page data on widget load.
  ///
  /// Calls [_loadOnlineData] to fetch scrap details and dropdown lists.
  @override
  void initState() {
    super.initState();
    _loadOnlineData();
  }

  /// Loads scrap details and dropdown data from server.
  ///
  /// Fetches:
  /// • Scrap detail data
  /// • Product list
  /// • Manufacturing Order list
  /// • Company list
  ///
  /// Also:
  /// • Parses date from server
  /// • Initializes text controllers
  /// • Sets selected dropdown values
  /// • Handles null or missing values safely
  Future<void> _loadOnlineData() async {
    final odooScrapService = ScrapService();
    await odooScrapService.initializeClient();
    final scrapId = int.parse(widget.scrap.id.toString());
    final response = await odooScrapService.loadScrapForm(scrapId);
    final productResponse = await odooScrapService.loadProduct();
    final moResponse = await odooScrapService.loadMo();
    final companyResponse = await odooScrapService.loadCompany();

    if (!mounted) return;

    String formattedDate = 'N/A';
    if (response != null && response.isNotEmpty) {
      final dateDone = response[0]['date_done'];
      if (dateDone != null && dateDone is String && dateDone.isNotEmpty) {
        DateTime parsedDate = DateTime.parse("${dateDone}Z").toLocal();
        formattedDate = DateFormat('MM/dd/yyyy HH:mm:ss').format(parsedDate);
      }
    }

    setState(() {
      scrapItem = response ?? [];
      productItem = productResponse ?? [];
      moItem = moResponse ?? [];
      companyItem = companyResponse ?? [];

      /// Initialize controllers and selected dropdown values
      if (scrapItem.isNotEmpty) {
        productController = TextEditingController(
          text:
              (scrapItem[0]['product_id'] != null &&
                  scrapItem[0]['product_id'] is List &&
                  scrapItem[0]['product_id'].length > 1)
              ? scrapItem[0]['product_id'][1].toString()
              : 'N/A',
        );
        selectedProduct =
            scrapItem[0]['product_id'] != null &&
                scrapItem[0]['product_id'] is List
            ? {
                'id': scrapItem[0]['product_id'][0],
                'name': scrapItem[0]['product_id'][1],
              }
            : null;
        moController = TextEditingController(
          text:
              (scrapItem[0]['production_id'] != null &&
                  scrapItem[0]['production_id'] is List &&
                  scrapItem[0]['production_id'].length > 1)
              ? scrapItem[0]['production_id'][1].toString()
              : 'N/A',
        );

        selectedMO =
            scrapItem[0]['production_id'] != null &&
                scrapItem[0]['production_id'] is List
            ? {
                'id': scrapItem[0]['production_id'][0],
                'name': scrapItem[0]['production_id'][1],
              }
            : null;
        final origin = scrapItem[0]['origin'];
        String originText;

        if (origin == null || origin == false) {
          originText = 'N/A';
        } else {
          originText = origin.toString();
        }

        sourceController = TextEditingController(text: originText);

        dateController = TextEditingController(text: formattedDate);
        companyController = TextEditingController(
          text:
              (scrapItem[0]['company_id'] != null &&
                  scrapItem[0]['company_id'] is List &&
                  scrapItem[0]['company_id'].length > 1)
              ? scrapItem[0]['company_id'][1].toString()
              : 'N/A',
        );
        selectedCompany =
            scrapItem[0]['company_id'] != null &&
                scrapItem[0]['company_id'] is List
            ? {
                'id': scrapItem[0]['company_id'][0],
                'name': scrapItem[0]['company_id'][1],
              }
            : null;
        quantityController = TextEditingController(
          text: scrapItem[0]['scrap_qty'].toString(),
        );
      }
      isLoading = false;
    });
  }

  /// Builds Product row UI.
  ///
  /// Shows:
  /// • Dropdown when editing
  /// • Text view when read-only
  Widget _productRow(bool isDark) {
    return isEditing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Product', isDark),
              _productDropdown(isDark, productController),
              SizedBox(height: 12),
            ],
          )
        : _viewRow('Product', productController.text, isDark);
  }

  /// Builds Manufacturing Order row UI.
  Widget _moRow(bool isDark) {
    return isEditing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Manufacturing Order', isDark),
              _moDropdown(isDark, moController),
              SizedBox(height: 12),
            ],
          )
        : _viewRow('Manufacturing Order', moController.text, isDark);
  }

  /// Builds Date row UI.
  Widget _dateRow(bool isDark) {
    return isEditing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Date', isDark),
              _datePickerField(isDark, dateController),
              SizedBox(height: 12),
            ],
          )
        : _viewRow('Date', dateController.text, isDark);
  }

  /// Builds Quantity row UI.
  Widget _quantityRow(bool isDark) {
    return isEditing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Quantity', isDark),
              _quantityField(isDark, quantityController),
              SizedBox(height: 12),
            ],
          )
        : _viewRow('Quantity', quantityController.text, isDark);
  }

  Widget _viewRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds Company row UI.
  Widget _companyRow(bool isDark) {
    return isEditing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Company', isDark),
              _companyDropdown(isDark, companyController),
              SizedBox(height: 12),
            ],
          )
        : _viewRow('Company', companyController.text, isDark);
  }

  /// Builds Source Document row UI.
  Widget _sourceRow(bool isDark) {
    return isEditing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Source Document', isDark),
              TextFormField(
                controller: sourceController,
                decoration: _textFieldDecoration(
                  isDark,
                  'Enter Source Document',
                ),
              ),
              SizedBox(height: 12),
            ],
          )
        : _viewRow('Source Document', sourceController.text, isDark);
  }

  /// Builds label text for form fields.
  Widget _fieldLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Product dropdown with search support.
  ///
  /// Updates:
  /// • Selected product ID
  /// • Selected product name
  /// • Controller text
  Widget _productDropdown(bool isDark, TextEditingController controller) {
    return DropdownSearch<Map<String, dynamic>>(
      key: const ValueKey("productDropdown"),
      enabled: isEditing,
      popupProps: PopupProps.menu(
        showSearchBox: true,
        menuProps: MenuProps(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        searchFieldProps: TextFieldProps(
          decoration: const InputDecoration(
            labelText: "Search Product",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      items: productItem,
      itemAsString: (item) => item?['name'] ?? '',
      selectedItem: selectedProduct,
      onChanged: (value) {
        setState(() {
          selectedProduct = value;
          if (value != null) {
            controller.text = value['name'];
            selectedProductId = value['id'];
            selectedProductName = value['name'];
          }
        });
      },
      dropdownDecoratorProps: _dropdownDecoration(isDark, "Select Product"),
    );
  }

  /// Manufacturing Order dropdown with search.
  Widget _moDropdown(bool isDark, TextEditingController controller) {
    return DropdownSearch<Map<String, dynamic>>(
      key: const ValueKey("moDropdown"),
      enabled: isEditing,
      popupProps: PopupProps.menu(
        showSearchBox: true,
        menuProps: MenuProps(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            labelText: "Search Manufacturing Order",
            labelStyle: TextStyle(fontWeight: FontWeight.w400),
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      items: moItem,
      itemAsString: (item) => item?['name'] ?? '',
      selectedItem: selectedMO,
      onChanged: (value) {
        setState(() {
          selectedMO = value;
          if (value != null) {
            controller.text = value['name'];
            selectedMOId = value['id'];
            selectedMOName = value['name'];
          }
        });
      },
      dropdownDecoratorProps: _dropdownDecoration(
        isDark,
        "Select Manufacturing Order",
      ),
    );
  }

  /// Company dropdown with search.
  Widget _companyDropdown(bool isDark, TextEditingController controller) {
    return DropdownSearch<Map<String, dynamic>>(
      key: const ValueKey("companyDropdown"),
      enabled: isEditing,
      popupProps: PopupProps.menu(
        showSearchBox: true,
        menuProps: MenuProps(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        searchFieldProps: TextFieldProps(
          decoration: InputDecoration(
            labelText: "Search Company",
            labelStyle: TextStyle(fontWeight: FontWeight.w400),
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      items: companyItem,
      itemAsString: (item) => item?['name'] ?? '',
      selectedItem: selectedCompany,
      onChanged: (value) {
        setState(() {
          selectedCompany = value;
          if (value != null) {
            controller.text = value['name'];
            selectedCompanyId = value['id'];
            selectedCompanyName = value['name'];
          }
        });
      },
      dropdownDecoratorProps: _dropdownDecoration(isDark, "Select Company"),
    );
  }

  /// Common dropdown decoration styling.
  DropDownDecoratorProps _dropdownDecoration(bool isDark, String hint) {
    return DropDownDecoratorProps(
      dropdownSearchDecoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.transparent,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.white : AppStyle.primaryColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  /// Date & Time picker field.
  ///
  /// Opens:
  /// • Date picker
  /// • Time picker
  ///
  /// Combines selected values into formatted string.
  Widget _datePickerField(bool isDark, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: _textFieldDecoration(isDark, "Select Date & Time"),
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );

        if (pickedDate == null) return;

        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );

        if (pickedTime == null) return;

        final dateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        controller.text =
            "${dateTime.toIso8601String().split('T')[0]} "
            "${pickedTime.hour.toString().padLeft(2, '0')}:"
            "${pickedTime.minute.toString().padLeft(2, '0')}:00";
      },
    );
  }

  /// Quantity input field.
  Widget _quantityField(bool isDark, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: _textFieldDecoration(isDark, "Enter Quantity"),
    );
  }

  /// Common text field decoration styling.
  InputDecoration _textFieldDecoration(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      filled: true,
      fillColor: isDark ? Colors.white10 : Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.transparent,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.white : AppStyle.primaryColor,
          width: 2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    if (scrapItem.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: Text(
            'Scrap Details',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.refreshScrap();
            },
          ),
        ),
        body: Container(
          width: double.infinity,
          color: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFB),
          child: const LoadingFormShimmer(itemCount: 6),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        widget.refreshScrap?.call();
        return false;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: Text(
            'Scrap Details',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              HugeIcons.strokeRoundedArrowLeft01,
              color: isDark ? Colors.white : Colors.black,
              size: 28,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.refreshScrap();
            },
          ),
          actions: [
            if (isEditing) ...[
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: TextButton(
                  onPressed: () async {
                    final scrapService = ScrapService();
                    await scrapService.initializeClient();
                    DateTime utcDateTime = (dateTime ?? DateTime.now()).toUtc();
                    String formattedDateTime =
                        "${utcDateTime.year.toString().padLeft(4, '0')}-"
                        "${utcDateTime.month.toString().padLeft(2, '0')}-"
                        "${utcDateTime.day.toString().padLeft(2, '0')} "
                        "${utcDateTime.hour.toString().padLeft(2, '0')}:"
                        "${utcDateTime.minute.toString().padLeft(2, '0')}:"
                        "${utcDateTime.second.toString().padLeft(2, '0')}";

                    bool success = await scrapService
                        .updateScrap(scrapItem[0]['id'], {
                          'product_id':
                              selectedProductId ?? selectedProduct?['id'],
                          'production_id': selectedMOId ?? selectedMO?['id'],
                          'origin': sourceController.text,
                          'date_done': formattedDateTime,
                          'company_id':
                              selectedCompanyId ?? selectedCompany?['id'],
                          'scrap_qty': quantityController.text,
                        });

                    success
                        ? CustomSnackbar.showSuccess(
                            context,
                            'Scrap updated successfully',
                          )
                        : CustomSnackbar.showError(
                            context,
                            'Failed to update scrap',
                          );

                    if (success) {
                      await _loadOnlineData();
                      setState(() {
                        isEditing = false;
                      });
                      ReviewService().trackSignificantEvent();
                      Future.delayed(const Duration(seconds: 3), () {
                        ReviewService().checkAndShowRating(context);
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.grey[700] : Colors.white,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: theme.colorScheme.onBackground,
                      fontWeight: FontWeight.w500,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ] else ...[
              if (scrapItem[0]['state'] != 'done') ...[
                IconButton(
                  onPressed: () async {
                    setState(() {
                      isEditing = true;
                    });
                  },
                  tooltip: 'Edit Scrap',
                  icon: Icon(
                    HugeIcons.strokeRoundedPencilEdit02,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
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

                    if (scrapItem[0]['state'] != 'done') {
                      items.addAll([
                        PopupMenuItem(
                          value: 'validate',
                          child: Row(
                            children: [
                              Icon(
                                HugeIcons.strokeRoundedCheckmarkCircle01,
                                color: isDark ? Colors.white : Colors.black54,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "Validate",
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }

                    return items;
                  },
                  onSelected: (value) async {
                    switch (value) {
                      case 'validate':
                        final scrapService = ScrapService();
                        await scrapService.initializeClient();

                        final response = await scrapService.validateScrap(
                          scrapItem[0]['id'],
                        );

                        if (response == true) {
                          await _loadOnlineData();
                          CustomSnackbar.showSuccess(
                            context,
                            'Scrap validated successfully',
                          );
                          ReviewService().trackSignificantEvent();
                          Future.delayed(const Duration(seconds: 3), () {
                            ReviewService().checkAndShowRating(context);
                          });
                        } else if (response is Map &&
                            response['res_model'] ==
                                'stock.warn.insufficient.qty.scrap') {
                          final ctx = response['context'] ?? {};
                          final qty = ctx['default_quantity'] ?? '';
                          final uom = ctx['default_product_uom_name'] ?? '';

                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: isDark
                                  ? Colors.grey[800]
                                  : Colors.white,
                              title: const Text(
                                "Insufficient Quantity To Scrap",
                              ),
                              content: Text(
                                "The product is not available in sufficient quantity.\n\n"
                                "Do you confirm you want to scrap $qty $uom?\n\n"
                                "This may lead to inconsistencies in your inventory.",
                              ),
                              actions: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? const Color(0xFF2A2A2A)
                                        : Colors.white,
                                    foregroundColor: isDark
                                        ? Colors.white
                                        : AppStyle.primaryColor,
                                  ),
                                  onPressed: () async {
                                    final scrapService = ScrapService();
                                    await scrapService.initializeClient();

                                    bool success = await scrapService
                                        .confirmScrap(
                                          scrapId: scrapItem[0]['id'],
                                          productId:
                                              selectedProductId ??
                                              selectedProduct?['id'],
                                          locationId:
                                              ctx['default_location_id'],
                                          uom: uom,
                                          qty: qty,
                                        );

                                    Navigator.of(context).pop();

                                    if (success) {
                                      await _loadOnlineData();
                                      CustomSnackbar.showSuccess(
                                        context,
                                        'Scrap validated successfully',
                                      );
                                      ReviewService().trackSignificantEvent();
                                      Future.delayed(const Duration(seconds: 3), () {
                                        ReviewService().checkAndShowRating(context);
                                      });
                                    } else {
                                      CustomSnackbar.showError(
                                        context,
                                        'Something went wrong, Please try again later',
                                      );
                                    }
                                  },
                                  child: Text(
                                    "Confirm",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            CustomSnackbar.showWarning(
                              context,
                              'Scrap forced despite insufficient quantity',
                            );
                          }
                        } else {
                          CustomSnackbar.showError(
                            context,
                            'Something went wrong, Please try again later',
                          );
                        }
                        break;
                    }
                  },
                ),
              ],
            ],
          ],
        ),
        body: isLoading
            ? Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
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
                width: double.infinity,
                color: isDark
                    ? const Color(0xFF121212)
                    : const Color(0xFFF8FAFB),
                child: const LoadingFormShimmer(itemCount: 6),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.white,
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
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          scrapItem[0]['name'],
                          _getStatus(scrapItem[0]['state'])['text']!,
                          _getStatus(scrapItem[0]['state'])['color']!,
                        ),
                        Divider(
                          height: 10,
                          color: isDark ? Colors.grey[700] : Colors.grey[200],
                        ),
                        _productRow(isDark),
                        _moRow(isDark),
                        _sourceRow(isDark),
                        _companyRow(isDark),
                        _dateRow(isDark),
                        _quantityRow(isDark),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Returns display status text and color based on scrap state.
  ///
  /// Example:
  /// • draft → Blue
  /// • done → Green
  Map<String, dynamic> _getStatus(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return {'text': 'Draft', 'color': Colors.blue};
      case 'done':
        return {'text': 'Done', 'color': Colors.green};
      default:
        return {'text': status.toUpperCase(), 'color': Colors.grey};
    }
  }

  /// Builds header section showing:
  /// • Scrap name
  /// • Status badge
  Widget _buildHeader(String name, String statusText, Color statusColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[900],
                letterSpacing: -0.3,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              border: Border.all(color: statusColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
