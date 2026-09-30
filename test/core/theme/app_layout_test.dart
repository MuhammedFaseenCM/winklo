import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_layout.dart';

void main() {
  testWidgets('marks short screens compact and tightens page padding', (
    tester,
  ) async {
    late AppLayout layout;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(320, 640)),
        child: Builder(
          builder: (context) {
            layout = AppLayout.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(layout.isCompact, isTrue);
    expect(layout.pagePadding.left, lessThan(24));
    expect(layout.sectionGap, lessThan(28));
    expect(layout.tileArtSize, lessThan(64));
  });

  testWidgets('keeps roomy spacing on design-size phones', (tester) async {
    late AppLayout layout;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: AppLayout.designSize),
        child: Builder(
          builder: (context) {
            layout = AppLayout.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(layout.isCompact, isFalse);
    expect(layout.pagePadding.left, closeTo(24, 0.01));
    expect(layout.sectionGap, closeTo(28, 0.01));
  });
}
