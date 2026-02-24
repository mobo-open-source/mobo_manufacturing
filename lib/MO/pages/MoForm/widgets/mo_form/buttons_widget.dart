import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../globals.dart';

import '../../bloc/mo_form/mo_form_bloc.dart';
import '../../bloc/mo_form/mo_form_event.dart';
import '../../bloc/mo_form/mo_form_state.dart';
import 'dialogs/scrap_products_dialog.dart';

/// Bottom action buttons section for the Manufacturing Order detail screen.
///
/// Displays context-sensitive action buttons based on the current MO state:
/// • Draft     → Confirm, Cancel
/// • In Progress / Confirmed → Produce All, Cancel, Scrap
/// • Done      → Unbuild, Scrap
/// • Cancelled → no actions
///
/// All buttons dispatch corresponding events to `MoFormBloc`.
class ButtonsWidget extends StatelessWidget {
  const ButtonsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MoFormBloc, MoFormState>(
      builder: (context, state) {
        // Early return if no MO data is loaded yet
        if (state.moItem.isEmpty) {
          return const SizedBox.shrink();
        }
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final moItem = state.moItem;
        final isDraft = moItem.isNotEmpty && moItem[0]['state'] == 'draft';
        final isDone = moItem.isNotEmpty && moItem[0]['state'] == 'done';
        final isCancelled = moItem.isNotEmpty && moItem[0]['state'] == 'cancel';

        final moFormBloc = context.read<MoFormBloc>();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.settings_rounded,
                      color: AppStyle.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Manufacturing Actions',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Main action buttons (responsive with Wrap)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // ─── Draft state actions ───────────────────────────────────────
                  if (isDraft) ...[
                    // Confirm MO (moves to confirmed, usually generates work orders)
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<MoFormBloc>().add(ConfirmMo(moItem));
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        "Confirm",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyle.primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppStyle.primaryColor.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    // Cancel MO (sets state to cancel)
                    OutlinedButton.icon(
                      onPressed: () {
                        context.read<MoFormBloc>().add(CancelMo(moItem));
                      },
                      icon: const Icon(Icons.cancel_rounded, size: 18),
                      label: Text(
                        "Cancel",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.white
                            : AppStyle.primaryColor,
                        side: BorderSide(
                          color: isDark
                              ? Colors.white60
                              : AppStyle.primaryColor,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],

                  // ─── Confirmed / In Progress state actions ─────────────────────
                  if (!isCancelled && !isDraft) ...[
                    if (!isDone) ...[
                      // Produce All (marks MO as done)
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<MoFormBloc>().add(ProduceAllMo(moItem));
                        },
                        icon: const Icon(
                          Icons.precision_manufacturing_rounded,
                          size: 18,
                        ),
                        label: Text(
                          "Produce All",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.green.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      // Cancel (from confirmed/in progress)
                      OutlinedButton.icon(
                        onPressed: () {
                          context.read<MoFormBloc>().add(CancelMo(moItem));
                        },
                        icon: const Icon(Icons.cancel_rounded, size: 18),
                        label: Text(
                          "Cancel",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.red,
                          side: BorderSide(
                            color: isDark ? Colors.white60 : Colors.red,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    // ─── Done state action ───────────────────────────────────────
                    if (isDone) ...[
                      // Unbuild (reverse production)
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<MoFormBloc>().add(UnbuildMo(moItem));
                        },
                        icon: const Icon(Icons.build_circle_rounded, size: 18),
                        label: Text(
                          "Unbuild",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.orange.withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    // ─── Common action: Scrap ───────────────────────────────────
                    OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => ScrapProductsDialog(
                            productScrap: state.productScrap,
                            isDraft: isDraft,
                            onScrap: (productId, quantity, replenishQty) {
                              moFormBloc.add(
                                ScrapMo({
                                  'product_id': productId,
                                  'scrap_qty': quantity,
                                  'should_replenish': replenishQty,
                                  'production_id': moItem[0]['id'],
                                }),
                              );
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(
                        "Scrap",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.red,
                        side: BorderSide(
                          color: isDark ? Colors.white60 : Colors.red,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
