import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/providers/motion_provider.dart';
import '../../../../../globals.dart';

import 'package:provider/provider.dart';

import '../../bloc/mo_form/mo_form_bloc.dart';
import '../../pages/mo_overview_page.dart';
import '../../pages/product_move_page.dart';
import '../../pages/scraps_page.dart';
import '../../pages/traceability_page.dart';
import '../../pages/unbuild_page.dart';

/// Smart action tabs / quick-access buttons displayed below the MO header.
///
/// Shows context-sensitive navigation buttons based on:
/// • Current MO state (draft, done, etc.)
/// • Counts of related records (unbuilds, scraps)
/// • User settings (show/hide certain tabs)
///
/// Each button opens a dedicated page using a fade transition (skipped if reduce motion is enabled).
class SmartTabsWidget extends StatelessWidget {
  /// Main MO record (used to check state and counts like unbuild_count, scrap_count)
  final List<dynamic> moItem;

  /// List of unbuild records (passed to UnbuildPage)
  final List<dynamic> unbuildOrders;

  /// List of scrap records (passed to ScrapPage)
  final List<dynamic> scrapProduct;

  const SmartTabsWidget({
    super.key,
    required this.moItem,
    required this.unbuildOrders,
    required this.scrapProduct,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MoFormBloc>().state;
    final motionProvider = Provider.of<MotionProvider>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // ─── Unbuilds button (only if count > 0) ───────────────────────
              if (moItem.isNotEmpty && moItem[0]['unbuild_count'] > 0)
                _buildSmartButton(
                  context,
                  icon: Icons.refresh,
                  label: "Unbuilds (${moItem[0]['unbuild_count']})",
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            UnbuildPage(unbuildOrders: unbuildOrders),
                        transitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        reverseTransitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              if (motionProvider.reduceMotion) return child;
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                ),

              // ─── Scraps button (only if count > 0) ─────────────────────────
              if (moItem.isNotEmpty && moItem[0]['scrap_count'] > 0)
                _buildSmartButton(
                  context,
                  icon: Icons.compare_arrows,
                  label: "Scraps (${moItem[0]['scrap_count']})",
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            ScrapPage(scrapProduct: scrapProduct),
                        transitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        reverseTransitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              if (motionProvider.reduceMotion) return child;
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                ),

              // ─── Overview button (controlled by user setting) ──────────────
              if (state.showOverviewSmartTab)
                _buildSmartButton(
                  context,
                  icon: Icons.dashboard,
                  label: "Overview",
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            MOOverviewPage(
                              moItem: moItem,
                              moveProducts: state.moveProducts,
                              workOrders: state.workOrders,
                            ),
                        transitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        reverseTransitionDuration: motionProvider.reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              if (motionProvider.reduceMotion) return child;
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                      ),
                    );
                  },
                ),

              // ─── Done-state specific tabs ──────────────────────────────────
              if (moItem.isNotEmpty && moItem[0]['state'] == 'done') ...[
                if (state.showProductMoveSmartTab)
                  _buildSmartButton(
                    context,
                    icon: Icons.move_to_inbox,
                    label: "Product Move",
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ProductMovePage(
                                    moItem: moItem,
                                    moveProducts: state.moveProducts,
                                  ),
                          transitionDuration: motionProvider.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          reverseTransitionDuration: motionProvider.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                if (motionProvider.reduceMotion) return child;
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                        ),
                      );
                    },
                  ),

                // Traceability tab (controlled by user setting)
                if (state.showTraceabilitySmartTab)
                  _buildSmartButton(
                    context,
                    icon: Icons.track_changes,
                    label: "Traceability",
                    onPressed: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  TraceabilityPage(
                                    moItem: moItem,
                                    moveProducts: state.moveProducts,
                                  ),
                          transitionDuration: motionProvider.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          reverseTransitionDuration: motionProvider.reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                                if (motionProvider.reduceMotion) return child;
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a consistent elevated button style used for all smart tabs.
  Widget _buildSmartButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        foregroundColor: isDark ? Colors.white : AppStyle.primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isDark
                ? Colors.white
                : AppStyle.primaryColor.withOpacity(0.7),
            width: 1.5,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppStyle.primaryColor,
        ),
      ),
    );
  }
}
