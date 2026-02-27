import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_switch/flutter_switch.dart';
import '../../../../../globals.dart';

import '../../bloc/mo_form/mo_form_bloc.dart';
import '../../bloc/mo_form/mo_form_event.dart';
import '../../models/product.dart';
import '../../models/stock_move.dart';
import 'dialogs/add_product_line_dialog.dart';
import 'dialogs/edit_product_line_dialog.dart';

/// Tab content widget displaying the list of components (stock moves / raw materials)
/// required for the Manufacturing Order.
///
/// Features:
/// • Header row with columns: Product, To Consume, (optional) Quantity + Consumed toggle
/// • Clickable rows to edit existing lines (opens EditProductLineDialog)
/// • "+ Add a line" button to create new component lines (opens AddProductLineDialog)
/// • Consumed toggle (picked flag) for tracking real consumption during production
/// • Responsive layout using Expanded flex columns
/// • Conditional visibility based on MO state (draft, done, cancelled)
class ProductTableWidget extends StatelessWidget {
  final List<StockMove> moveProducts;
  final bool isDraft;
  final bool isDone;
  final bool isCancel;
  final List<Product> products;

  /// Callback when user taps a product row to edit it
  final Function(StockMove, int) onProductTapped;

  /// Callback to trigger showing the add line dialog
  final Function() onAddProductLine;

  /// Callback when user toggles the "Consumed" switch
  final Function(int, bool) onConsumeUpdated;

  const ProductTableWidget({
    super.key,
    required this.moveProducts,
    required this.isDraft,
    required this.isDone,
    required this.isCancel,
    required this.products,
    required this.onProductTapped,
    required this.onAddProductLine,
    required this.onConsumeUpdated,
  });

  /// Builds a modern-looking switch using FlutterSwitch package
  Widget _buildModernSwitch(
    BuildContext context,
    bool value,
    Function(bool) onChanged,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: FlutterSwitch(
        value: value,
        onToggle: onChanged,
        width: 52,
        height: 32,
        toggleSize: 24,
        borderRadius: 16.0,
        padding: 3.0,
        activeColor: isDark ? Colors.white : Theme.of(context).primaryColor,
        inactiveColor: isDark ? Colors.white38 : Colors.black54,
        activeToggleColor: isDark ? Colors.black : Colors.white,
        inactiveToggleColor: Colors.white,
        duration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Table Header ───────────────────────────────────────────────
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
                if (!isDraft) ...[
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Quantity",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "Consumed",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),

          // ─── Table Rows (one per stock move) ─────────────────────────────
          ...moveProducts.asMap().entries.map((entry) {
            int index = entry.key;
            StockMove product = entry.value;
            return GestureDetector(
              // Open edit dialog on tap (disabled when done)
              onTap: () {
                if (!isDone) {
                  onProductTapped(product, index);
                  final moFormBloc = context.read<MoFormBloc>();
                  showDialog(
                    context: context,
                    builder: (context) => EditProductLineDialog(
                      product: product,
                      index: index,
                      products: products,
                      isDraft: isDraft,
                      onSave: (productId, productName, quantity, toConsume) {
                        moFormBloc.add(
                          UpdateProductMove(
                            productMoveId: product.id,
                            productId: productId,
                            productName: productName,
                            quantity: quantity,
                            toConsume: toConsume,
                          ),
                        );
                      },
                      onDelete: () {
                        moFormBloc.add(DeleteProductMove(product.id));
                      },
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        product.productId?[1]?.toString() ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        product.toConsume.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    if (!isDraft) ...[
                      Expanded(
                        flex: 2,
                        child: Text(
                          product.quantity.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildModernSwitch(
                          context,
                          product.picked == true,
                          (bool value) {
                            if (!isDone) {
                              onConsumeUpdated(product.id, value);
                            }
                          },
                          isDark,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          // ─── Add Line Button ─────────────────────────────────────────────
          if (!isDone && !isCancel)
            GestureDetector(
              onTap: () {
                onAddProductLine();

                final moFormBloc = context.read<MoFormBloc>();

                showDialog(
                  context: context,
                  builder: (context) => AddProductLineDialog(
                    products: products,
                    isDraft: isDraft,
                    onAdd: (productId, productName, toConsume, quantity) {
                      final moId = int.parse(
                        moFormBloc.state.moItem[0]['id'].toString(),
                      );
                      moFormBloc.add(
                        AddProductToLine(
                          moId: moId,
                          productId: productId,
                          productName: productName,
                          toConsume: toConsume,
                          quantity: quantity,
                          moProductId:
                              moFormBloc.state.moItem[0]['product_id'][0],
                        ),
                      );
                    },
                  ),
                );
              },
              child: Text(
                "+ Add a line",
                style: TextStyle(
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
