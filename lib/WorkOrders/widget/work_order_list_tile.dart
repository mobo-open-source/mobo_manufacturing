import 'package:flutter/material.dart';
import 'package:mobo_manufacturing_app/globals.dart';
import '../model/work_order.dart';

/// Compact list tile widget for displaying a single Work Order in list views.
///
/// Shows:
/// - Operation name + Work Center
/// - Product & Quantity
/// - Expected vs Real Duration
/// - Status badge with color-coded meaning
/// - Action buttons: Start / Pause / Done (conditionally shown)
///
/// Features:
/// - Dark/light mode support
/// - Loading indicators during start/pause/done actions
/// - Real-time elapsed duration display (passed from provider/timer)
class WorkOrderListTile extends StatelessWidget {
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
  final bool isLoading;
  final bool isDoneLoading;

  const WorkOrderListTile({
    super.key,
    required this.workOrder,
    required this.isBlocked,
    required this.realDuration,
    this.isStarted = false,
    this.onStart,
    this.onPause,
    this.onDone,
    this.isLoading = false,
    this.isDoneLoading = false,
  });

  /// Formats Duration into compact HH:mm:ss or mm:ss string
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

  /// Returns color for status badge based on work order state
  Color getStatusColor() {
    switch (workOrder.status.toLowerCase()) {
      case 'pending':
        return Colors.teal;
      case 'waiting':
        return Colors.amber;
      case 'ready':
        return Colors.blue;
      case 'progress':
        return Colors.orange;
      case 'done':
        return Colors.green;
      case 'cancel':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  /// Returns human-readable status text (overrides raw Odoo state)
  String getStatusText() {
    switch (workOrder.status.toLowerCase()) {
      case 'pending':
        return 'Waiting for another WO';
      case 'waiting':
        return 'Waiting for Components';
      case 'ready':
        return 'Ready';
      case 'progress':
        return 'In Progress';
      case 'done':
        return 'Finished';
      case 'cancel':
        return 'Cancelled';
      default:
        return workOrder.status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = getStatusColor();
    final statusText = getStatusText();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.05),
              offset: const Offset(0, 6),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 14,
            top: 14,
            bottom: 14,
            right: 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),

              // Operation + Status badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Operation: ${workOrder.operation}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            'Work Center: ${workOrder.workCenter}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(isDark, statusColor, statusText),
                ],
              ),
              SizedBox(height: 4),

              // Product + Quantity
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Product: ${workOrder.product}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${workOrder.quantity} Units',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Expected vs Real Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expected Duration',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),

                      Text(
                        workOrder.formattedExpectedDuration,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Real Duration',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(realDuration),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (workOrder.status.toLowerCase() != 'done' &&
                      workOrder.status.toLowerCase() != 'cancel') ...[
                    if (!isStarted) ...[
                      ElevatedButton(
                        onPressed: isLoading ? null : onStart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : AppStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),

                        child: isLoading
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            backgroundColor: Colors.transparent,
                            color: isDark? Colors.grey[600]: Colors.white,
                          ),
                        )
                            : Text(
                          'Start',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        onPressed:  isLoading ? null : onPause,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            backgroundColor: Colors.transparent,
                            color: isDark? Colors.white: AppStyle.primaryColor,
                          ),
                        )
                            :Text(
                          'Pause',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : AppStyle.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: isLoading ? null : onDone,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white
                              : AppStyle.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:  isDoneLoading
                            ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            backgroundColor: Colors.transparent,
                            color: isDark? Colors.grey[600]: Colors.white,
                          ),
                        )
                            : Text(
                          'Done',
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
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
      ),
    );
  }

  /// Builds the status badge (pill-shaped with color)
  Widget _buildStatusBadge(bool isDark, Color statusColor, String statusText) {
    final textColor = isDark ? Colors.white : statusColor;
    final backgroundColor = isDark
        ? Colors.white.withOpacity(0.15)
        : statusColor.withOpacity(0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isDark ? FontWeight.bold : FontWeight.w600,
          color: textColor,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
