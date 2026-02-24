import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../globals.dart';
import 'package:hugeicons/hugeicons.dart';
import '../bloc/product_move/product_move_bloc.dart';
import '../bloc/product_move/product_move_event.dart';
import '../bloc/product_move/product_move_state.dart';
import '../models/stock_move.dart';
import '../widgets/status_product_move_chip.dart';
import 'package:intl/intl.dart';

/// Full-screen page displaying inventory/stock move history for a Manufacturing Order (MO).
///
/// Shows a horizontal-scrollable `DataTable` with:
/// • MO-level move (produced item)
/// • Component/raw material moves (from `moveProducts`)
///
/// Columns: Date, Reference, Product, Lot/Serial, From, To, Quantity, Status
///
/// Uses `ProductMoveBloc` to load additional move line details (e.g. lot/serial numbers).
/// Formats dates and handles dark/light theme.
/// Includes back button and loading/error states.
class ProductMovePage extends StatelessWidget {
  /// Main MO record (Odoo-style list/map)
  final List<dynamic> moItem;

  /// List of raw material/component stock moves
  final List<StockMove> moveProducts;

  const ProductMovePage({
    super.key,
    required this.moItem,
    required this.moveProducts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final rawDate = moItem[0]['date_finished'];
    DateTime parsedDate = DateTime.parse("${rawDate}Z").toLocal();
    String formattedDate = DateFormat('MM/dd/yyyy HH:mm:ss').format(parsedDate);
    return BlocProvider(
      // Initialize bloc with MO and moves data
      create: (_) =>
          ProductMoveBloc(moItem: moItem, moveProducts: moveProducts)
            ..add(LoadProductMoveEvent()),
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: Text(
            'Inventory Moves',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 22,
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
            },
          ),
          automaticallyImplyLeading: false,
        ),
        body: BlocBuilder<ProductMoveBloc, ProductMoveState>(
          builder: (context, state) {
            if (state is ProductMoveLoading) {
              return Center(
                child: LoadingAnimationWidget.fourRotatingDots(
                  color: isDark ? Colors.white : AppStyle.primaryColor,
                  size: 50,
                ),
              );
            } else if (state is ProductMoveError) {
              return Center(child: Text('Error: ${state.message}'));
            } else if (state is ProductMoveLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  // ─── Table Columns ────────────────────────────────────────────
                  columns: [
                    DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Reference',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Product',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Lot/Serial Number',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'From',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'To',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Quantity',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],

                  // ─── Table Rows ───────────────────────────────────────────────
                  rows: [
                    // MO-level produced item row
                    DataRow(
                      cells: [
                        DataCell(Text(formattedDate ?? '-')),
                        DataCell(Text(moItem[0]['name'] ?? '-')),
                        DataCell(
                          Text(
                            moItem[0]['product_id'] is List
                                ? (moItem[0]['product_id'][1]?.toString() ??
                                      '-')
                                : '-',
                          ),
                        ),
                        DataCell(
                          Text(
                            (moItem[0]['lot_producing_id'] is List &&
                                    moItem[0]['lot_producing_id'].length > 1)
                                ? moItem[0]['lot_producing_id'][1].toString()
                                : '-',
                          ),
                        ),
                        DataCell(
                          Text(
                            moItem[0]['production_location_id'] is List
                                ? (moItem[0]['production_location_id']?[1] ??
                                      '-')
                                : '-',
                          ),
                        ),
                        DataCell(
                          Text(
                            moItem[0]['location_dest_id'] is List
                                ? (moItem[0]['location_dest_id']?[1] ?? '-')
                                : '-',
                          ),
                        ),
                        DataCell(
                          Text(moItem[0]['product_qty']?.toString() ?? '0.00'),
                        ),
                        DataCell(buildMoveStatus(moItem[0]["state"], isDark)),
                      ],
                    ),

                    // Component move rows (one per stock move)
                    ...List.generate(moveProducts.length, (index) {
                      final move = moveProducts[index];

                      List<dynamic>? moveLine;
                      if (state.moveLines.isNotEmpty &&
                          state.moveLines.length > index &&
                          state.moveLines[index] is List &&
                          (state.moveLines[index] as List).isNotEmpty) {
                        moveLine = state.moveLines[index] as List;
                      }

                      // Try to get lot/serial from loaded move lines
                      String lotName = '-';
                      if (moveLine != null) {
                        final line = moveLine.first;
                        if (line is Map &&
                            line['lot_id'] is List &&
                            (line['lot_id'] as List).length > 1) {
                          lotName = line['lot_id'][1].toString();
                        }
                      }

                      return DataRow(
                        cells: [
                          DataCell(Text(formattedDate ?? '-')),
                          DataCell(Text(moItem[0]['name'] ?? '-')),
                          DataCell(Text(move.productId?[1] ?? '-')),
                          DataCell(Text(lotName)),
                          DataCell(Text(move.locationId?[1] ?? '-')),
                          DataCell(Text(move.locationDestId?[1] ?? '-')),
                          DataCell(
                            Text(move.quantity?.toStringAsFixed(2) ?? '0.00'),
                          ),
                          DataCell(buildMoveStatus(moItem[0]["state"], isDark)),
                        ],
                      );
                    }),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
