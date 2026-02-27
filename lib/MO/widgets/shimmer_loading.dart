import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder for MO list loading state
class ManufacturingOrderShimmer extends StatelessWidget {
  const ManufacturingOrderShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark?Color(0xFF2A2A2A):Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Container(height: 16, width: 100, color: Colors.white),
              subtitle: Container(
                margin: const EdgeInsets.only(top: 8),
                height: 14,
                width: 150,
                color: Colors.white,
              ),
              trailing: Container(height: 20, width: 60, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}
