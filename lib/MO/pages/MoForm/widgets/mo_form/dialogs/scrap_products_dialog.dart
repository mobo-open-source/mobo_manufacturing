import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../../../../../globals.dart';

import '../../../models/product.dart';

/// Dialog for scrapping one or more components/materials from a Manufacturing Order.
///
/// Allows the user to:
/// • Select a product from the list of scrappable items
/// • Enter the quantity to scrap
/// • Optionally check "Replenish Quantities" (triggers stock replenishment)
/// • Validates product selection
/// • Calls `onScrap(productId, quantity, shouldReplenish)` callback on confirm
class ScrapProductsDialog extends StatefulWidget {
  final List<Product> productScrap;
  final bool isDraft;
  final Function(int, double, bool) onScrap;

  const ScrapProductsDialog({
    super.key,
    required this.productScrap,
    required this.isDraft,
    required this.onScrap,
  });

  @override
  State<ScrapProductsDialog> createState() => _ScrapProductsDialogState();
}

class _ScrapProductsDialogState extends State<ScrapProductsDialog> {
  int? selectedProductScrap;
  String? selectedProductScrapName;
  double quantity = 1.0;
  bool replenishQty = false;
  String errorMessage = '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Scrap Products",
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SizedBox(
        // Dynamic height: larger when error is shown
        height: errorMessage.isNotEmpty
            ? MediaQuery.of(context).size.height * 0.25
            : (widget.isDraft
                  ? MediaQuery.of(context).size.height * 0.15
                  : MediaQuery.of(context).size.height * 0.22),
        width: MediaQuery.of(context).size.width * 0.95,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Product Selection ──────────────────────────────────────────
            DropdownSearch<Map<String, dynamic>>(
              popupProps: PopupProps.menu(
                showSearchBox: true,
                // Limit popup height based on number of items
                constraints: BoxConstraints(
                  maxHeight: (widget.productScrap.length <= 3)
                      ? widget.productScrap.length * 150
                      : 300,
                ),
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: "Search Product",
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),

                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              items: widget.productScrap.map((p) => p.toJson()).toList(),
              itemAsString: (item) => item?['name'] ?? '',
              selectedItem: widget.productScrap
                  .firstWhere(
                    (element) => element.id == selectedProductScrap,
                    orElse: () => Product(id: 0, name: ''),
                  )
                  .toJson(),
              onChanged: (value) {
                setState(() {
                  selectedProductScrap = value?['id'];
                  selectedProductScrapName = value?['name'];
                });
              },
              dropdownDecoratorProps: DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: "Select Product",
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),

                  prefixIcon: Icon(Icons.inventory_2),
                  border: OutlineInputBorder(),
                ),
              ),
              validator: (value) =>
                  value == null ? 'Please select a product' : null,
            ),
            const SizedBox(height: 16),

            // ─── Scrap Quantity ─────────────────────────────────────────────
            TextFormField(
              initialValue: quantity.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  quantity = double.tryParse(value) ?? 1.0;
                });
              },
            ),
            const SizedBox(height: 16),

            // ─── Replenish Checkbox ─────────────────────────────────────────
            Row(
              children: [
                Checkbox(
                  value: replenishQty,
                  onChanged: (value) {
                    setState(() {
                      replenishQty = value ?? false;
                    });
                  },
                ),
                Text(
                  'Replenish Quantities',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),

            // Error message
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
      actions: [
        Row(
          children: [
            // ─── Cancel Button ──────────────────────────────────────────────
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
                  "CANCEL",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ─── Scrap Button ───────────────────────────────────────────────
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (selectedProductScrap == null) {
                    setState(() {
                      errorMessage = "Please select a product.";
                    });
                    return;
                  }
                  widget.onScrap(selectedProductScrap!, quantity, replenishQty);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white
                      : AppStyle.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: Text(
                  "Scrap",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.black : Colors.white,
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
