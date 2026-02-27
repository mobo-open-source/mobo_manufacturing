import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../../../globals.dart';

import '../../../models/product.dart';

/// Dialog for adding a new component/product line (stock move) to a Manufacturing Order.
///
/// Features:
/// • Dropdown to select a product from the provided list
/// • Input field for "To Consume" quantity (always shown)
/// • Optional "Produced Quantity" field (shown only when MO is **not** in draft state)
/// • Validates product selection
/// • Shows loading indicator during add operation
/// • Returns data via callback `onAdd(productId, productName, toConsume, quantity)`
class AddProductLineDialog extends StatefulWidget {
  /// List of available products to choose from
  final List<Product> products;
  final bool isDraft;

  /// Callback invoked when user confirms adding the line
  /// Parameters: (productId, productName, toConsumeQty, producedQty)
  final Function(int, String, double, double) onAdd;

  const AddProductLineDialog({
    super.key,
    required this.products,
    required this.isDraft,
    required this.onAdd,
  });

  @override
  State<AddProductLineDialog> createState() => _AddProductLineDialogState();
}

class _AddProductLineDialogState extends State<AddProductLineDialog> {
  // Controllers for quantity inputs
  final TextEditingController qtyToConsumeController = TextEditingController(
    text: '0',
  );
  final TextEditingController qtyController = TextEditingController(text: '0');
  int? selectedMo;
  String? selectedMoName;
  String errorMessage = '';
  bool isLoading = false;

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
              'Add Product Line',
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
        // Dynamic height depending on error visibility and draft status
        height: errorMessage.isNotEmpty
            ? MediaQuery.of(context).size.height * 0.32
            : (widget.isDraft
                  ? MediaQuery.of(context).size.height * 0.20
                  : MediaQuery.of(context).size.height * 0.25),
        width: MediaQuery.of(context).size.width * 0.95,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  Column(
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
                            items: widget.products
                                .map((p) => p.toJson())
                                .toList(),
                            itemAsString: (item) => item?['name'] ?? '',
                            selectedItem: selectedMo != null
                                ? widget.products
                                      .firstWhere(
                                        (element) => element.id == selectedMo,
                                        orElse: () => Product(id: 0, name: ''),
                                      )
                                      .toJson()
                                : null,

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
                                ? 'Please select a product'
                                : null,
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
                      if (!widget.isDraft) ...[
                        const SizedBox(height: 16),

                        // ─── Produced Quantity (only when not draft) ──────────────────
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
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black87,
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

                      // Error message display
                      if (errorMessage.isNotEmpty)
                        Text(
                          errorMessage,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Loading overlay
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
            // Cancel button
            Expanded(
              child: OutlinedButton(
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

            // Add button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  final enteredToConsumeQty =
                      double.tryParse(qtyToConsumeController.text.trim()) ??
                      0.0;
                  final enteredQty =
                      double.tryParse(qtyController.text.trim()) ?? 0.0;
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
                  widget.onAdd(
                    selectedMo!,
                    selectedMoName ?? 'Unnamed',
                    enteredToConsumeQty,
                    enteredQty,
                  );
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                  setState(() {
                    isLoading = false;
                  });
                },
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
              ),
            ),
          ],
        ),
      ],
    );
  }
}
