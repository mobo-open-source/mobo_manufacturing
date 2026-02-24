import 'package:flutter/material.dart';
import '../../globals.dart';
import '../model/work_order.dart';

/// Card widget displaying a single Work Order (mrp.workorder) in list views.
///
/// Shows:
/// - Operation name & status badge
/// - Work center & product
/// - Quantity & durations (expected + real/elapsed)
/// - Action buttons: Start / Pause / Done (conditionally shown)
///
/// Supports:
/// - Dark/light mode styling
/// - Blocked state indication (can be styled further if needed)
/// - Real-time elapsed duration display (passed from provider/timer)
class WorkOrderCard extends StatelessWidget {
  /// The work order data to display
  final WorkOrder workOrder;

  /// Whether this work order is currently blocked (productivity loss active)
  final bool isBlocked;

  /// Whether the work order timer is currently running
  final bool isStarted;

  /// Current real elapsed duration (live value from timer manager)
  final Duration realDuration;

  final Function()? onStart;
  final Function()? onPause;
  final Function()? onDone;
  final Function()? onBlock;
  final Function()? onUnblock;

  const WorkOrderCard({
    super.key,
    required this.workOrder,
    required this.isBlocked,
    required this.realDuration,
    this.isStarted = false,
    this.onStart,
    this.onPause,
    this.onDone,
    this.onBlock,
    this.onUnblock,
  });

  /// Formats a Duration into HH:mm:ss or mm:ss string
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '00:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine status badge appearance
    Color statusColor;
    String statusText;

    switch (workOrder.status.toLowerCase()) {
      case 'pending':
        statusText = 'Waiting for another WO';
        statusColor = Colors.teal;
        break;
      case 'waiting':
        statusText = 'Waiting for Components';
        statusColor = Colors.amber;
        break;
      case 'ready':
        statusText = 'Ready';
        statusColor = Colors.blue;
        break;
      case 'progress':
        statusText = 'In Progress';
        statusColor = Colors.orange;
        break;
      case 'done':
        statusText = 'Finished';
        statusColor = Colors.green;
        break;
      case 'cancel':
        statusText = 'Cancelled';
        statusColor = Colors.redAccent;
        break;
      default:
        statusText = workOrder.status.toUpperCase();
        statusColor = Colors.grey;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Operation + Status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Operation: ${workOrder.operation}",
                    style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : AppStyle.primaryColor,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Work Center & Product
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Work Center: ${workOrder.workCenter}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Product: ${workOrder.product}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quantity & Expected Duration
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quantity: ${workOrder.quantity}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Expected Duration: ${workOrder.formattedExpectedDuration}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Real Duration (live)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Real Duration: ${_formatDuration(realDuration)}',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons (conditional)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (workOrder.status.toLowerCase() != 'done') ...[
                  if (!isStarted) ...[
                    ElevatedButton(
                      onPressed: onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark? Colors.white: AppStyle.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),

                      child: Text(
                        'Start',
                        style: TextStyle(color: isDark? Colors.black: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else ...[
                    ElevatedButton(
                      onPressed: onPause,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: isDark? Colors.white: AppStyle.primaryColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Pause',
                        style: TextStyle(color: isDark? Colors.white: AppStyle.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Done button
                    ElevatedButton(
                      onPressed: onDone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark? Colors.white: AppStyle.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(color: isDark? Colors.black: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
