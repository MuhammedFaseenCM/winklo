import 'package:flutter/material.dart';

import '../../../../core/widgets/app_shimmer.dart';

/// Board + bottom-chrome loading placeholder for Zip (replaces a spinner).
class ZipShimmer extends StatelessWidget {
  const ZipShimmer({super.key, this.gridSize = 6});

  final int gridSize;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (var row = 0; row < gridSize; row++) ...[
                      if (row > 0) const SizedBox(height: 6),
                      Expanded(
                        child: Row(
                          children: [
                            for (var col = 0; col < gridSize; col++) ...[
                              if (col > 0) const SizedBox(width: 6),
                              const Expanded(
                                child: AppShimmerBox(
                                  height: double.infinity,
                                  borderRadius: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(child: AppShimmerBox(height: 48, borderRadius: 24)),
                  SizedBox(width: 12),
                  Expanded(child: AppShimmerBox(height: 48, borderRadius: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
