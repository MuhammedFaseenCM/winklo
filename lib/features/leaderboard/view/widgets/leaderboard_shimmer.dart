import 'package:flutter/material.dart';

import '../../../../core/widgets/app_shimmer.dart';
import 'leaderboard_table.dart';

/// Skeleton of the board table: a header strip and [rowCount] rows shaped
/// like [LeaderboardTableRow] (rank · avatar · name · time).
class LeaderboardShimmer extends StatelessWidget {
  const LeaderboardShimmer({super.key, this.rowCount = 10});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
          child: DecoratedBox(
            decoration: leaderboardTableDecoration(),
            child: AppShimmer(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 30,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppShimmerBox(
                            width: 64,
                            height: 8,
                            borderRadius: 4,
                          ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < rowCount; i++)
                      const _LeaderboardRowShimmer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardRowShimmer extends StatelessWidget {
  const _LeaderboardRowShimmer();

  @override
  Widget build(BuildContext context) {
    // Mirrors LeaderboardTableRow: 56px, rank 28, avatar r=14, time 56.
    return const SizedBox(
      height: leaderboardTableRowHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Center(
                child: AppShimmerBox(width: 14, height: 14, borderRadius: 4),
              ),
            ),
            SizedBox(width: 10),
            AppShimmerCircle(radius: 14),
            SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: AppShimmerBox(width: 120, height: 12, borderRadius: 4),
              ),
            ),
            AppShimmerBox(width: 40, height: 14, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}
