import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../../globals.dart';
import 'package:hugeicons/hugeicons.dart';
import '../bloc/mo_overview/mo_overview_bloc.dart';
import '../bloc/mo_overview/mo_overview_event.dart';
import '../bloc/mo_overview/mo_overview_state.dart';
import '../models/mo_work_order.dart';
import '../models/stock_move.dart';
import '../service/pdf_generator.dart';

/// Full-screen overview page for a Manufacturing Order (MO).
///
/// Displays:
/// • A header card with key MO information
/// • A material/components table (stock moves)
/// • PDF download button in the AppBar
///
/// Uses `MOOverviewBloc` to manage loading states and UI sections.
/// Shows a centered loading animation during PDF generation.
/// Supports dark/light theme.
class MOOverviewPage extends StatefulWidget {
  /// Main MO record (usually a list with one map from Odoo response)
  final List<dynamic> moItem;

  /// List of raw material stock moves (components)
  final List<StockMove> moveProducts;

  /// List of work orders for this MO
  final List<MoWorkOrder> workOrders;

  const MOOverviewPage({
    super.key,
    required this.moItem,
    required this.moveProducts,
    required this.workOrders,
  });

  @override
  State<MOOverviewPage> createState() => _MOOverviewPageState();
}

class _MOOverviewPageState extends State<MOOverviewPage> {
  /// Controls visibility of full-screen loading overlay during PDF generation
  bool isDownloading = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocProvider(
      // Initialize bloc with initial data and theme
      create: (_) => MOOverviewBloc(
        isDark: isDark,
        moItem: widget.moItem,
        moveProducts: widget.moveProducts,
        workOrders: widget.workOrders,
      )..add(LoadMOOverviewEvent()),
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
          title: Text(
            'MO Overview',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
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
          actions: [
            // ─── PDF Download Button ────────────────────────────────────────
            TextButton.icon(
              onPressed: () async {
                setState(() {
                  isDownloading = true;
                });
                final pdfGenerator = PdfGenerator(
                  moItem: widget.moItem,
                  workOrders: widget.workOrders,
                  moveProducts: widget.moveProducts,
                  context: context,
                );
                await pdfGenerator.generateAndSavePdf();
                setState(() {
                  isDownloading = false;
                });
              },
              icon: Icon(
                Icons.picture_as_pdf,
                color: isDark ? Colors.white : AppStyle.primaryColor,
              ),
              label: Text(
                "Download PDF",
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BlocBuilder<MOOverviewBloc, MOOverviewState>(
            builder: (context, state) {
              if (state is MOOverviewLoading) {
                return Center(
                  child: LoadingAnimationWidget.fourRotatingDots(
                    color: isDark ? Colors.white : AppStyle.primaryColor,
                    size: 50,
                  ),
                );
              } else if (state is MOOverviewLoaded) {
                return Stack(
                  children: [
                    // Main scrollable content
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header card (summary info)
                          state.headerCard,
                          // Materials/components table
                          state.materialTable,
                        ],
                      ),
                    ),

                    // ─── Full-screen overlay during PDF generation ─────────────
                    if (isDownloading)
                      Positioned.fill(
                        child: Center(
                          child: LoadingAnimationWidget.fourRotatingDots(
                            color: isDark ? Colors.white : AppStyle.primaryColor,
                            size: 50,
                          ),
                        ),
                      ),
                  ],
                );
              } else if (state is MOOverviewError) {
                return Center(
                  child: Text(
                    'Error: ${state.message}',
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              // Fallback for unhandled states
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
