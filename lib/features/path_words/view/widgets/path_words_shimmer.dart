import 'package:flutter/material.dart';

import '../../../../core/widgets/app_shimmer.dart';

/// Board-shaped loading placeholder for Path Words (replaces a spinner).
class PathWordsShimmer extends StatelessWidget {
  const PathWordsShimmer({super.key, this.gridSize = 5});

  final int gridSize;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
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
    );
  }
}
