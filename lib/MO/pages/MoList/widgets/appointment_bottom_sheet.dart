import 'package:flutter/material.dart';
import 'package:mobo_manufacturing_app/MO/pages/MoList/model/mo_event.dart';
import '../../../../globals.dart';
import 'package:intl/intl.dart';

/// Bottom sheet displayed when tapping a Manufacturing Order (MO) event on the calendar.
///
/// Shows key details of the selected MO (date, responsible, product, quantity)
/// and provides an "Edit" button to navigate to the MO form.
class AppointmentBottomSheet extends StatelessWidget {
  final MOEvent appointment;
  final Map<String, dynamic> item;
  final VoidCallback onEdit;

  const AppointmentBottomSheet({
    super.key,
    required this.appointment,
    required this.item,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              height: 5,
              width: 50,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Title (MO name/reference)
          Text(
            appointment.subject ?? 'MO Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          // Key information rows
          _buildInfoRow(
            context,
            "Date",
            DateFormat('dd/MM/yyyy hh:mm').format(appointment.startTime),
          ),
          _buildInfoRow(
            context,
            "Responsible",
            item['user_id'] is List ? item['user_id'][1] ?? 'N/A' : 'N/A',
          ),
          _buildInfoRow(
            context,
            "Product",
            item['product_id'] is List ? item['product_id'][1] ?? 'N/A' : 'N/A',
          ),
          _buildInfoRow(
            context,
            "Qty",
            item['product_qty']?.toString() ?? 'N/A',
          ),
          const SizedBox(height: 16),

          // Edit action button
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onEdit,
                  label: const Text(
                    "Edit Manufacturing Order",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white
                        : AppStyle.primaryColor,
                    foregroundColor: isDark
                        ? Colors.black
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a label-value row for displaying MO information
  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label ",
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white70 : const Color(0xff7F7F7F),
            ),
          ),
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
}
