import 'package:flutter/material.dart';
import '../../globals.dart';
import 'package:intl/intl.dart';

/// Bottom sheet for selecting a scheduled date range filter (start + end date).
///
/// Used in the MO list/calendar view to filter Manufacturing Orders by planned/scheduled dates.
/// Features:
/// - Date pickers for start and end dates
/// - "Clear Filter" button (shown only when filter is active)
/// - "Apply Filter" button to confirm selection
class FilterBottomSheet extends StatelessWidget {
  final DateTime? initialScheduleDate;
  final DateTime? initialEndDate;
  final Function(DateTime?, DateTime?) onApply;
  final Function() onClear;
  final bool isFilterApplied;

  const FilterBottomSheet({
    super.key,
    required this.initialScheduleDate,
    required this.initialEndDate,
    required this.onApply,
    required this.onClear,
    required this.isFilterApplied,
  });

  @override
  Widget build(BuildContext context) {
    // Local mutable state for dates (updated via setModalState)
    DateTime? modalScheduledDate = initialScheduleDate;
    DateTime? modalEndDate = initialEndDate;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Header with title + clear button (if filter active)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Options',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppStyle.primaryColor,
                        ),
                      ),
                      if (isFilterApplied)
                        ElevatedButton(
                          onPressed: () {
                            onClear();
                            Navigator.pop(context);
                          },
                          child: Text(
                            "Clear Filter",
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : AppStyle.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Start date picker tile
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      modalScheduledDate == null
                          ? 'Select Scheduled Date'
                          : DateFormat(
                              'yyyy-MM-dd',
                            ).format(modalScheduledDate!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.calendar_today,
                      color: AppStyle.primaryColor,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: modalScheduledDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() {
                          modalScheduledDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // End date picker tile
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      modalEndDate == null
                          ? 'Select End Date'
                          : DateFormat('yyyy-MM-dd').format(modalEndDate!),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    trailing: Icon(
                      Icons.calendar_today,
                      color: AppStyle.primaryColor,
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: modalEndDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() {
                          modalEndDate = picked;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text(
                        'Apply Filter',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyle.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        onApply(modalScheduledDate, modalEndDate);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
