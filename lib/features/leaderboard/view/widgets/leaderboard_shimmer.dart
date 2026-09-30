import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_shimmer.dart';

/// Skeleton matching [LeaderboardRow] list layout (rank · avatar · name · time).
class LeaderboardShimmer extends StatelessWidget {
  const LeaderboardShimmer({super.key, this.rowCount = 8});

  final int rowCount;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: layout.pagePadding,
        itemCount: rowCount,
        separatorBuilder: (_, _) => SizedBox(height: layout.space(8)),
        itemBuilder: (_, _) => const _LeaderboardRowShimmer(),
      ),
    );
  }
}

class _LeaderboardRowShimmer extends StatelessWidget {
  const _LeaderboardRowShimmer();

  @override
  Widget build(BuildContext context) {
    // Mirrors LeaderboardRow: padding 14/12, radius 14, rank 28, avatar r=18.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ZipColors.wall,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 28,
            child: Center(
              child: AppShimmerBox(width: 18, height: 18, borderRadius: 4),
            ),
          ),
          AppShimmerCircle(radius: 18),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(width: 120, height: 14, borderRadius: 4),
                SizedBox(height: 6),
                AppShimmerBox(width: 48, height: 10, borderRadius: 4),
              ],
            ),
          ),
          AppShimmerBox(width: 40, height: 16, borderRadius: 4),
        ],
      ),
    );
  }
}
