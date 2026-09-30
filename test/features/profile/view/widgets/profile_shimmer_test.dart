import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/app_shimmer.dart';
import 'package:winklo/features/profile/view/widgets/profile_shimmer.dart';

void main() {
  testWidgets('ProfileShimmer exposes circle and boxes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: ProfileShimmer()),
      ),
    );
    expect(find.byType(AppShimmerCircle), findsOneWidget);
    expect(find.byType(AppShimmerBox), findsWidgets);
  });
}
