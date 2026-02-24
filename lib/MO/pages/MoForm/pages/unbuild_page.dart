import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Full-screen page displaying the list of unbuild orders related to a Manufacturing Order (MO).
///
/// Shows a horizontal-scrollable `DataTable` with the following columns:
/// • Reference
/// • Product
/// • Bill of Material
/// • Manufacturing Order
/// • Lot/Serial Number
/// • Quantity
/// • Company
/// • Status (with colored background: green for done, orange for draft, grey otherwise)
///
/// Supports dark/light theme.
/// Includes back button in AppBar.
/// Assumes `unbuildOrders` contains Odoo-style records from `mrp.unbuild` model.
class UnbuildPage extends StatelessWidget {
  final List<dynamic> unbuildOrders;

  const UnbuildPage({super.key, required this.unbuildOrders});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        title: Text(
          'Unbuild Orders',
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  // ─── Table Columns ─────────────────────────────────────────────
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
                        'Bill of Material',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Manufacturing Order',
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
                        'Quantity',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Company',
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

                  // ─── Table Rows ─────────────────────────────────────────────────
                  rows: unbuildOrders.map((item) {
                    return DataRow(
                      cells: [
                        DataCell(Text(item['name']?.toString() ?? 'N/A')),
                        DataCell(
                          Text(
                            item['product_id'] is List
                                ? (item['product_id'][1]?.toString() ?? 'N/A')
                                : 'N/A',
                          ),
                        ),
                        DataCell(
                          Text(
                            item['bom_id'] is List
                                ? (item['bom_id'][1]?.toString() ?? 'N/A')
                                : 'N/A',
                          ),
                        ),
                        DataCell(
                          Text(
                            item['mo_id'] is List
                                ? (item['mo_id'][1]?.toString() ?? 'N/A')
                                : 'N/A',
                          ),
                        ),
                        DataCell(
                          Text(
                            item['lot_id'] is List
                                ? (item['lot_id'][1]?.toString() ?? 'N/A')
                                : 'N/A',
                          ),
                        ),
                        DataCell(
                          Text(item['product_qty']?.toString() ?? 'N/A'),
                        ),
                        DataCell(
                          Text(
                            item['company_id'] is List
                                ? (item['company_id'][1]?.toString() ?? 'N/A')
                                : 'N/A',
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (item['state'] == 'done')
                                  ? Colors.green.withOpacity(0.2)
                                  : (item['state'] == 'draft')
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              (item['state'] == 'done')
                                  ? 'Done'
                                  : (item['state'] == 'draft')
                                  ? 'Draft'
                                  : item['state']?.toString() ?? 'N/A',
                              style: TextStyle(
                                color: (item['state'] == 'done')
                                    ? Colors.green
                                    : (item['state'] == 'draft')
                                    ? Colors.orange
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
