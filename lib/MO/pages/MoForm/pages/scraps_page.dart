import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

class ScrapPage extends StatelessWidget {
  final List<dynamic> scrapProduct;

  const ScrapPage({super.key, required this.scrapProduct});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        title: Text(
          'Scrap Orders',
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
                        'Date',
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
                  rows: scrapProduct.map((item) {
                    String formattedDate;
                    final rawDate = item['date_done'];

                    if (rawDate != null &&
                        rawDate.toString().isNotEmpty &&
                        rawDate != false) {
                      try {
                        final rawDateString = rawDate.toString();
                        if (RegExp(
                          r'^\d{4}-\d{2}-\d{2}',
                        ).hasMatch(rawDateString)) {
                          DateTime parsedDate = DateTime.parse(
                            "${rawDateString}Z",
                          ).toLocal();
                          formattedDate = DateFormat(
                            'MM/dd/yyyy HH:mm:ss',
                          ).format(parsedDate);
                        } else {
                          formattedDate = 'N/A';
                        }
                      } catch (e) {
                        formattedDate = 'N/A';
                      }
                    } else {
                      formattedDate = 'N/A';
                    }

                    return DataRow(
                      cells: [
                        DataCell(Text(item['name']?.toString() ?? 'N/A')),
                        DataCell(Text(formattedDate)),
                        DataCell(
                          Text(
                            item['product_id'] is List
                                ? (item['product_id'][1]?.toString() ?? 'N/A')
                                : 'N/A',
                          ),
                        ),
                        DataCell(Text(item['scrap_qty']?.toString() ?? 'N/A')),
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
