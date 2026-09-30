import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/app_shimmer.dart';

void main() {
  testWidgets('AppShimmerBox and AppShimmerCircle build under AppShimmer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: AppShimmer(
            child: Column(
              children: [
                AppShimmerCircle(radius: 24),
                AppShimmerBox(width: 120, height: 16),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(AppShimmerCircle), findsOneWidget);
    expect(find.byType(AppShimmerBox), findsOneWidget);
  });
}
