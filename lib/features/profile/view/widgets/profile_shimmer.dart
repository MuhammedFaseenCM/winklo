import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/widgets/app_shimmer.dart';

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return AppShimmer(
      child: SingleChildScrollView(
        padding: layout.pagePadding,
        child: Column(
          children: [
            const Center(child: AppShimmerCircle(radius: 56)),
            SizedBox(height: layout.space(16)),
            const Center(child: AppShimmerBox(width: 140, height: 22)),
            SizedBox(height: layout.space(8)),
            const Center(child: AppShimmerBox(width: 120, height: 14)),
            SizedBox(height: layout.space(12)),
            SizedBox(
              width: double.infinity,
              child: AppShimmerBox(height: 180, borderRadius: 16),
            ),
          ],
        ),
      ),
    );
  }
}
