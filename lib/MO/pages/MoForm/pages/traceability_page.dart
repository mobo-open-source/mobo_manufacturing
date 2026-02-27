import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../globals.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import '../bloc/traceability/traceability_bloc.dart';
import '../bloc/traceability/traceability_event.dart';
import '../bloc/traceability/traceability_state.dart';
import '../models/stock_move.dart';

/// Full-screen traceability report page for a Manufacturing Order (MO).
///
/// Displays a horizontal-scrollable `DataTable` showing the full traceability chain:
/// • MO-level produced item row (with lot/serial if available)
/// • One row per component/raw material move
/// • Expandable sub-row for inventory adjustment/stock effect (when expanded)
///
/// Uses `TraceabilityBloc` to load detailed move line information (especially lot/serial numbers).
/// Supports dark/light theme, includes back button, and handles loading/error states.
class TraceabilityPage extends StatelessWidget {
  final List<dynamic> moItem;
  final List<StockMove> moveProducts;

  const TraceabilityPage({
    super.key,
    required this.moItem,
    required this.moveProducts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocProvider(
      // Initialize bloc with MO and moves data
      create: (_) =>
          TraceabilityBloc(moItem: moItem, moveProducts: moveProducts)
            ..add(LoadTraceabilityEvent()),
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: Text(
            'Traceability Report',
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
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: BlocBuilder<TraceabilityBloc, TraceabilityState>(
            builder: (context, state) {
              if (state is TraceabilityLoading) {
                return Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    size: 50,
                  ),
                );
              } else if (state is TraceabilityError) {
                return Center(child: Text('Error: ${state.message}'));
              } else if (state is TraceabilityLoaded) {
                return TraceabilityDataTable(
                  moItem: moItem,
                  moveProducts: moveProducts,
                  productDetails: state.productDetails,
                  moveLines: state.moveLines,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

/// Expandable `DataTable` widget that displays traceability information for the MO.
///
/// Features:
/// • First row: MO produced item (with lot/serial if available)
/// • One row per component move, with expand/collapse icon
/// • When expanded: shows inventory adjustment/stock effect row
/// • Horizontal scrolling for wide content
/// • Dark/light theme support
class TraceabilityDataTable extends StatefulWidget {
  final List<dynamic> moItem;
  final List<StockMove> moveProducts;
  final List<dynamic> productDetails;
  final List<dynamic> moveLines;

  const TraceabilityDataTable({
    super.key,
    required this.moItem,
    required this.moveProducts,
    required this.productDetails,
    required this.moveLines,
  });

  @override
  State<TraceabilityDataTable> createState() => _TraceabilityDataTableState();
}

class _TraceabilityDataTableState extends State<TraceabilityDataTable> {
  /// Tracks which component rows are expanded (shows inventory adjustment sub-row)
  late List<bool> isExpanded;

  @override
  void initState() {
    super.initState();

    // Initialize all rows as collapsed
    isExpanded = List.filled(widget.moveProducts.length, false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ─── Build table rows ─────────────────────────────────────────────────
    List<DataRow> dataRows = [];

    final rawDate = widget.moItem[0]['date_finished'];
    DateTime parsedDate = DateTime.parse("${rawDate}Z").toLocal();
    String formattedDate = DateFormat('MM/dd/yyyy HH:mm:ss').format(parsedDate);

    // 1. MO-level produced item row (always shown)
    dataRows.add(
      DataRow(
        cells: [
          DataCell(
            Text(
              widget.moItem[0]['name'] ?? '-',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DataCell(
            Text(
              widget.productDetails.isNotEmpty
                  ? widget.productDetails[0]['name'] ?? '-'
                  : '-',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DataCell(
            Text(
              formattedDate ?? '-',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DataCell(
            Text(
              (widget.moItem[0]['lot_producing_id'] is List &&
                      widget.moItem[0]['lot_producing_id']!.length > 1)
                  ? widget.moItem[0]['lot_producing_id'][1].toString()
                  : '-',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DataCell(
            Text(
              'Production',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DataCell(
            Text(
              widget.moItem[0]['location_dest_id'] is List
                  ? (widget.moItem[0]['location_dest_id'][1] ?? '-')
                  : '-',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DataCell(
            Text(
              widget.moItem[0]['product_qty'].toString(),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );

    // 2. Component move rows (expandable)
    for (int i = 0; i < widget.moveProducts.length; i++) {
      final move = widget.moveProducts[i];
      final moveLine = widget.moveLines.length > i ? widget.moveLines[i] : null;

      dataRows.add(
        DataRow(
          cells: [
            // Expand/collapse icon
            DataCell(
              IconButton(
                icon: Icon(
                  isExpanded[i]
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                onPressed: () {
                  setState(() {
                    isExpanded[i] = !isExpanded[i];
                  });
                },
              ),
            ),
            DataCell(Text(move.productId?[1] ?? '-')),
            DataCell(Text(formattedDate ?? '-')),
            DataCell(
              Text(
                moveLine != null && moveLine.isNotEmpty
                    ? (moveLine[0]['lot_id'] is List
                          ? moveLine[0]['lot_id'][1].toString()
                          : moveLine[0]['lot_id'].toString())
                    : '-',
              ),
            ),
            DataCell(Text(move.locationId?[1] ?? '-')),
            DataCell(Text(move.locationDestId?[1] ?? '-')),
            DataCell(Text(move.quantity.toString())),
          ],
        ),
      );

      // ─── Expanded inventory adjustment row ──────────────────────────────
      if (isExpanded[i]) {
        dataRows.add(
          DataRow(
            cells: [
              const DataCell(Text('')),
              DataCell(Text('Inventory Adjustment')),

              DataCell(Text(formattedDate ?? '-')),
              DataCell(
                Text(
                  moveLine != null && moveLine.isNotEmpty
                      ? (moveLine[0]['lot_id'] is List
                            ? moveLine[0]['lot_id'][1].toString()
                            : moveLine[0]['lot_id'].toString())
                      : '-',
                ),
              ),
              const DataCell(Text("Inventory adjustment")),
              const DataCell(Text('Stock')),
              DataCell(
                Text(
                  ((move.productVirtualAvailable ?? 0) + (move.quantity ?? 0))
                      .toString(),
                ),
              ),
            ],
          ),
        );
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        // ─── Table Columns ──────────────────────────────────────────────────
        columns: [
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
              'Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Lot/Serial #',
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
        ],
        rows: dataRows,
      ),
    );
  }
}
