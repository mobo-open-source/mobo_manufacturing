import 'package:flutter/material.dart';
import '../models/mo_work_order.dart';
import '../models/stock_move.dart';
import '../service/mo_form_service.dart';
import 'package:intl/intl.dart';
import 'status_chip.dart';

/// Builds the header summary card widget for the MO Overview page.
///
/// This card displays:
/// • MO name/title
/// • Produced product name + status chip
/// • Ordered quantity
/// • Unit cost of the main product
/// • Total estimated MO cost (based on component availability or to-consume qty)
/// • Total real cost (based on to-consume qty)
/// • Expected receipt/finish date (formatted)
///
/// Fetches additional product details from Odoo when needed.
/// Uses dark/light theme awareness for styling.
Future<Widget> buildHeaderCard(
  bool isDark,
  List<dynamic> moItem,
  List<StockMove> moveProducts,
  List<MoWorkOrder> workOrders,
) async {
  final odooMoService = MoFormService();
  await odooMoService.initializeClient();

  // Fetch details of the main produced product
  List<dynamic> productDetails = await odooMoService.loadProductDetails(
    moItem[0]['product_id'][0],
  );

  // ─── Calculate total costs ──────────────────────────────────────────────
  double totalMoCost = 0;
  double totalRealCost = 0;

  for (var product in moveProducts) {
    List<dynamic> productDetails = await odooMoService.loadProductDetails(
      product.productId?[0],
    );
    double unitCost = productDetails[0]['standard_price'] ?? 0.0;

    // MO cost: use available qty if present, else planned to-consume
    double moCost = (product.availability != null && product.availability! > 0)
        ? product.availability! * unitCost
        : unitCost * (product.toConsume ?? 0.0);

    // Real cost: always based on to-consume (planned consumption)
    double realCost = unitCost * (product.toConsume ?? 0.0);

    totalMoCost += moCost;
    totalRealCost += realCost;
  }

  // ─── Format expected finish/receipt date ────────────────────────────────
  String formattedDate;
  if (moItem[0]['date_finished'] != null) {
    final rawDateFinished = moItem[0]['date_finished'];
    DateTime parsedDateFinished = DateTime.parse(
      "${rawDateFinished}Z",
    ).toLocal();
    formattedDate = DateFormat('MM/dd/yyyy').format(parsedDateFinished);
  } else {
    formattedDate = '-';
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 24),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // MO name / title
          Text(
            moItem[0]['name'] ?? 'Item Name',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade400, thickness: 1.2),
          const SizedBox(height: 12),

          // Product name + status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  moItem[0]['product_id'][1] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              buildStatusMrp(moItem[0]['state'], isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Quantity + Unit Cost
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: 'Quantity: ',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: '${moItem[0]['product_qty'] ?? 0}',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: 'Unit Cost: ',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text:
                            '${productDetails[0]['standard_price']?.toStringAsFixed(2) ?? 0.0}',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total MO Cost + Real Cost
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: 'MO Cost: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: totalMoCost.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: 'Real Cost: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextSpan(
                        text: totalRealCost.toStringAsFixed(2),
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Expected Receipt / Finish Date
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white : Colors.black87,
              ),
              children: [
                TextSpan(
                  text: 'Receipt: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                TextSpan(
                  text: "Expected $formattedDate",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Builds the horizontal-scrollable material/components table for the MO Overview page.
///
/// Displays:
/// • Header row: Description, Status, Quantity, Unit Cost, MO Cost, Real Cost
/// • One row per component (stock move)
/// • Operations section (work orders) with status chips and durations
/// • Total row with aggregated costs and operation hours
///
/// Fetches unit costs from Odoo for each component.
/// Calculates MO cost (availability-aware) and real cost (planned consumption).
Future<Widget> buildMaterialTable(
  bool isDark,
  List<StockMove> moveProducts,
  List<MoWorkOrder> workOrders,
) async {
  final odooMoService = MoFormService();
  await odooMoService.initializeClient();

  // ─── Prepare component rows ─────────────────────────────────────────────
  List<Map<String, dynamic>> materialsData = [];
  double totalMoCost = 0;
  double totalRealCost = 0;

  // ─── Calculate total operation time (in hours) ──────────────────────────
  double totalOperationQuantity = 0;

  for (var product in moveProducts) {
    List<dynamic> productDetails = await odooMoService.loadProductDetails(
      product.productId?[0],
    );
    double unitCost = productDetails[0]['standard_price'] ?? 0.0;

    // MO cost prefers available qty if present
    double moCost = (product.availability != null && product.availability! > 0)
        ? product.availability! * unitCost
        : unitCost * (product.toConsume ?? 0.0);
    double realCost = unitCost * (product.toConsume ?? 0.0);

    totalMoCost += moCost;
    totalRealCost += realCost;

    materialsData.add({
      'description': product.productId?[1] ?? 'Unnamed Product',
      'quantity': product.toConsume ?? 0.0,
      'unitCost': unitCost,
      'moCost': moCost,
      'realCost': realCost,
    });
  }
  for (var operation in workOrders) {
    final opQuantityStr = operation.formattedDuration ?? '0:00';
    final parts = opQuantityStr.split(':');

    if (parts.length == 2) {
      final hours = double.tryParse(parts[0]) ?? 0.0;
      final minutes = double.tryParse(parts[1]) ?? 0.0;

      totalOperationQuantity += hours + (minutes / 60);
    }
  }
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(200),
          1: FixedColumnWidth(180),
          2: FixedColumnWidth(100),
          3: FixedColumnWidth(100),
          4: FixedColumnWidth(100),
          5: FixedColumnWidth(100),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // ─── Header Row (only if there are materials) ─────────────────────
          if (materialsData.isNotEmpty)
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Quantity',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Unit Cost',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'MO Cost',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Real Cost',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),

          // ─── Component Rows ─────────────────────────────────────────────────
          ...materialsData.map(
            (data) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    data['description'],
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    data['quantity'].toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    data['unitCost'].toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    data['moCost'].toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    data['realCost'].toStringAsFixed(2),
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Operations Section Header ──────────────────────────────────────
          if (workOrders.isNotEmpty)
            TableRow(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[300],
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Operations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('')),
                Padding(padding: EdgeInsets.all(8.0), child: Text('')),
              ],
            ),

          // ─── Work Order Rows ────────────────────────────────────────────────
          ...workOrders.map(
            (operation) => TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    operation.operation ?? 'Unnamed Operation',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: buildStatusChip(operation.state, isDark),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    operation.formattedDuration ?? '0.00',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    operation.costs_hour?.toStringAsFixed(2) ?? '0.00',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const Padding(padding: EdgeInsets.all(8.0), child: Text('-')),
                const Padding(padding: EdgeInsets.all(8.0), child: Text('-')),
              ],
            ),
          ),

          // ─── Total Row ──────────────────────────────────────────────────────
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.all(8.0), child: Text('')),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  totalOperationQuantity.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              const Padding(padding: EdgeInsets.all(8.0), child: Text('')),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  totalMoCost.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  totalRealCost.toStringAsFixed(2),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
