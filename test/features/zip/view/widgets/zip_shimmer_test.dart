import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/app_shimmer.dart';
import 'package:winklo/features/zip/view/widgets/zip_shimmer.dart';

void main() {
  testWidgets('ZipShimmer builds grid and bottom chrome placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(height: 480, child: ZipShimmer())),
      ),
    );
    expect(find.byType(AppShimmer), findsOneWidget);
    expect(find.byType(AppShimmerBox), findsWidgets);
  });
}
