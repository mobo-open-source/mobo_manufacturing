import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../../../globals.dart';

import '../../../models/product.dart';
import '../../../models/stock_move.dart';

/// Dialog for editing an existing component/product line (stock move) in a Manufacturing Order.
///
/// Features:
/// • Pre-filled product selection (dropdown) and quantities
/// • Allows changing product, "To Consume" quantity, and (if not draft) produced "Quantity"
/// • "Delete" button to remove the line entirely
/// • Validates product selection
/// • Shows loading indicator during save/delete
/// • Calls `onSave` or `onDelete` callbacks and closes dialog
class EditProductLineDialog extends StatefulWidget {
  final StockMove product;
  final int index;
  final List<Product> products;
  final bool isDraft;

  /// Callback when user saves changes
  /// Parameters: (newProductId, newProductName, newQuantity, newToConsume)
  final Function(int, String, double, double) onSave;

  /// Callback when user wants to delete this line
  final Function() onDelete;

  const EditProductLineDialog({
    super.key,
    required this.product,
    required this.index,
    required this.products,
    required this.isDraft,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<EditProductLineDialog> createState() => _EditProductLineDialogState();
}

class _EditProductLineDialogState extends State<EditProductLineDialog> {
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController qtyToConsumeController = TextEditingController();
  int? selectedMo;
  String? selectedMoName;
  String errorMessage = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize fields from the existing stock move
    qtyController.text = widget.product.quantity.toString();
    qtyToConsumeController.text = widget.product.toConsume.toString();
    selectedMo = widget.product.productId?[0];
    selectedMoName = widget.product.productId?[1];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Edit Product Line',
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
        // Dynamic height: larger when error is shown or when Quantity field is visible
        height: errorMessage.isNotEmpty
            ? MediaQuery.of(context).size.height * 0.32
            : (widget.isDraft
                  ? MediaQuery.of(context).size.height * 0.23
                  : MediaQuery.of(context).size.height * 0.30),
        width: MediaQuery.of(context).size.width * 0.95,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10),

                  // ─── Product Selection ────────────────────────────────────────
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
                            style: TextStyle(fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: "Search Product",
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        items: widget.products.map((p) => p.toJson()).toList(),
                        itemAsString: (item) => item?['name'] ?? '',
                        selectedItem: widget.products
                            .firstWhere(
                              (element) => element.id == selectedMo,
                              orElse: () => Product(id: 0, name: ''),
                            )
                            .toJson(),
                        onChanged: (value) {
                          setState(() {
                            selectedMo = value?['id'];
                            selectedMoName = value?['name'];
                          });
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
                              color: isDark ? Colors.white60 : Colors.black87,
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
                        validator: (value) =>
                            value == null ? 'Please select a product' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── To Consume Quantity ──────────────────────────────────────
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
                        controller: qtyToConsumeController,
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
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
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
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),

                  // ─── Produced Quantity (only when not draft) ──────────────────
                  if (!widget.isDraft) ...[
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Quantity",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 5),
                        TextField(
                          controller: qtyController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintText: 'Quantity',
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
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Error display
                  if (errorMessage.isNotEmpty)
                    Text(
                      errorMessage,
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                ],
              ),
            ),

            // Loading overlay during save/delete
            if (isLoading)
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
        Row(
          children: [
            // ─── Delete Button ─────────────────────────────────────────────
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  setState(() {
                    isLoading = true;
                  });
                  widget.onDelete();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  setState(() {
                    isLoading = false;
                  });
                },
                label: Text(
                  'Delete',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                ),
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
              ),
            ),
            const SizedBox(width: 10),

            // ─── Save Button ───────────────────────────────────────────────
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final enteredQty =
                      double.tryParse(qtyController.text.trim()) ?? 0.0;
                  final enteredToConsumeQty =
                      double.tryParse(qtyToConsumeController.text.trim()) ??
                      0.0;
                  if (selectedMo == null) {
                    setState(() {
                      errorMessage = "Please select a product.";
                    });
                    return;
                  }
                  setState(() {
                    isLoading = true;
                    errorMessage = '';
                  });
                  widget.onSave(
                    selectedMo!,
                    selectedMoName ?? 'Unnamed',
                    enteredQty,
                    enteredToConsumeQty,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  setState(() {
                    isLoading = false;
                  });
                },
                label: Text(
                  'SAVE',
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
              ),
            ),
          ],
        ),
      ],
    );
  }
}
