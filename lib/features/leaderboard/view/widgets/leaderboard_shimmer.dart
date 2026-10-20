import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/widgets/app_shimmer.dart';
import 'leaderboard_table.dart';

/// Skeleton of the board: a three-step podium over [rowCount] rows shaped
/// like [LeaderboardTableRow] (rank · avatar · name · time).
class LeaderboardShimmer extends StatelessWidget {
  const LeaderboardShimmer({super.key, this.rowCount = 6});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    // Mirrors LeaderboardPodium: avatar plus ring, name, time, then the step.
    Widget place(int flex, double radius, double step) => Expanded(
      flex: flex,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppShimmerCircle(radius: layout.space(radius)),
          const SizedBox(height: 8),
          const AppShimmerBox(width: 56, height: 10, borderRadius: 4),
          const SizedBox(height: 6),
          const AppShimmerBox(width: 36, height: 12, borderRadius: 4),
          const SizedBox(height: 8),
          AppShimmerBox(
            width: double.infinity,
            height: layout.space(step),
            borderRadius: 10,
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: leaderboardTableMaxWidth),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppShimmer(
                  child: Padding(
                    // The crown's room above first place.
                    padding: EdgeInsets.fromLTRB(
                      4,
                      layout.space(6) + layout.space(23),
                      4,
                      10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        place(10, 23, 44),
                        const SizedBox(width: 8),
                        place(11, 28.5, 60),
                        const SizedBox(width: 8),
                        place(10, 23, 32),
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: leaderboardTableDecoration(),
                  child: AppShimmer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < rowCount; i++)
                          const _LeaderboardRowShimmer(),
                      ],
                    ),
                  ),
                ),
              ],
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
    // Mirrors LeaderboardTableRow: 52px, rank 28, avatar r=14, time 56.
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
