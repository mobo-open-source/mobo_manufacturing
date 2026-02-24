import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import '../../../../../globals.dart';

import '../../models/bom.dart';
import '../../models/product.dart';
import '../../models/user_model.dart';

/// Reusable row widget for displaying and editing a single detail field in the Manufacturing Order form.
///
/// Supports:
/// • Read-only display mode
/// • Editable mode with appropriate input (dropdown for Product/BOM/Responsible, number field for Quantity, date picker for dates)
/// • Conditional rendering based on `label` (Product, Bill of Material, Quantity, Responsible, Scheduled Date, End Date, etc.)
/// • Dark/light theme awareness
/// • Callbacks for value changes and edit tap events
class DetailRowWidget extends StatelessWidget {
  final String label;
  final String value;
  final bool isEditable;
  final Color? valueColor;
  final bool isEditing;
  final List<Bom> billOfMaterial;
  final List<Product> products;
  final List<UserModel> users;
  final Map<String, dynamic> moItem;

  // Callbacks for value changes (only called in edit mode)
  final ValueChanged<Map<String, dynamic>?>? onProductChanged;
  final ValueChanged<Map<String, dynamic>?>? onBomChanged;
  final ValueChanged<Map<String, dynamic>?>? onUserChanged;
  final ValueChanged<String>? onQtyChanged;
  final ValueChanged<DateTime>? onScheduleDateChanged;
  final ValueChanged<DateTime>? onEndDateChanged;

  /// Called when user taps the edit icon (if present in parent)
  final VoidCallback? onEditTapped;

  const DetailRowWidget({
    super.key,
    required this.label,
    required this.value,
    required this.isEditable,
    required this.isEditing,
    required this.billOfMaterial,
    required this.products,
    required this.users,
    required this.moItem,
    this.valueColor,
    this.onProductChanged,
    this.onBomChanged,
    this.onUserChanged,
    this.onQtyChanged,
    this.onScheduleDateChanged,
    this.onEndDateChanged,
    this.onEditTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: isEditing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  ),
                ),
                const SizedBox(height: 10),
                _buildEditableWidget(context),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.normal,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }

  /// Builds the appropriate editable input widget based on the field `label`.
  Widget _buildEditableWidget(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (label) {
      case 'Product':
        final selectedProductMap = moItem['product_id'] is List
            ? {
                'id': moItem['product_id'][0] ?? 0,
                'name': moItem['product_id'][1]?.toString() ?? '-',
              }
            : null;

        return DropdownSearch<Map<String, dynamic>>(
          key: ValueKey('product_${selectedProductMap?['id'] ?? 'null'}'),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                labelText: "Search Product",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey[100],
            ),
          ),
          items: products.map((p) => p.toJson()).toList(),
          itemAsString: (item) => item?['name']?.toString() ?? '',
          selectedItem: selectedProductMap,
          onChanged: (value) => onProductChanged?.call(value),
        );

      case 'Bill of Material':
        final selectedBomMap = moItem['bom_id'] is List
            ? {
                'id': moItem['bom_id'][0] ?? 0,
                'name': moItem['bom_id'][1]?.toString() ?? '-',
              }
            : null;

        return DropdownSearch<Map<String, dynamic>>(
          key: ValueKey('bom_${selectedBomMap?['id'] ?? 'null'}'),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                labelText: "Search BOM",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              hintText: "Select BOM",
              hintStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black87,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey[100],
            ),
          ),
          items: billOfMaterial.map((p) => p.toJson()).toList(),
          itemAsString: (item) => item?['name']?.toString() ?? '',
          selectedItem: selectedBomMap,
          onChanged: (value) => onBomChanged?.call(value),
        );

      case 'Quantity':
        final bool showProduce = moItem['show_produce'] == true;

        return Row(
          children: [
            SizedBox(
              width: 100,
              child: TextFormField(
                keyboardType: TextInputType.number,
                initialValue: showProduce
                    ? moItem['qty_produced']?.toString() ?? '0'
                    : moItem['product_qty']?.toString() ?? '0',
                onChanged: (val) => onQtyChanged?.call(val),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  hintText: "Qty",
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey[100],
                ),
              ),
            ),

            if (showProduce) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '/ ${moItem['product_qty'] ?? 0} To Produce',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        );

      case 'Responsible':
        final selectedUserMap = moItem['user_id'] is List
            ? {
                'id': moItem['user_id'][0] ?? 0,
                'name': moItem['user_id'][1]?.toString() ?? '-',
              }
            : null;

        return DropdownSearch<Map<String, dynamic>>(
          items: users.map((u) => u.toJson()).toList(),
          itemAsString: (item) => item?['name']?.toString() ?? '',
          selectedItem: selectedUserMap,
          dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              hintText: "Select Responsible",
              hintStyle: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black87,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey[100],
            ),
          ),
          onChanged: (value) => onUserChanged?.call(value),
        );

      case 'Scheduled Date':
        return _buildDatePicker(context, onScheduleDateChanged);

      case 'End Date':
        return _buildDatePicker(context, onEndDateChanged);

      default:
        return TextField(
          controller: TextEditingController(text: value),
          onSubmitted: (_) => onEditTapped?.call(),
        );
    }
  }

  /// Builds a tappable date input field that shows a date picker on tap.
  Widget _buildDatePicker(
    BuildContext context,
    ValueChanged<DateTime>? onDateChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () async {
        final initialDate = DateTime.tryParse(value) ?? DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (pickedDate != null) onDateChanged?.call(pickedDate);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          hintText: "Select Date",
          hintStyle: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
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
          filled: true,
          fillColor: isDark ? Colors.white10 : Colors.grey[100],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value.isEmpty ? "Select Date" : value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: value.isEmpty
                    ? (isDark ? Colors.white60 : Colors.black54)
                    : (isDark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
