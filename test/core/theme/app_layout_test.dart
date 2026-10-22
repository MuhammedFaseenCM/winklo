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
    expect(layout.pagePadding.left, lessThan(20));
    expect(layout.sectionGap, lessThan(12));
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
    expect(layout.pagePadding.left, closeTo(20, 0.01));
    expect(layout.sectionGap, closeTo(12, 0.01));
  });

  testWidgets('scroll padding clears the bottom inset (the nav dock)', (
    tester,
  ) async {
    late EdgeInsets padding;
    late AppLayout layout;
    // scrollPadding reads viewPadding (home indicator), not padding.
    const homeIndicator = 34.0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: AppLayout.designSize,
          viewPadding: EdgeInsets.only(bottom: homeIndicator),
          padding: EdgeInsets.only(bottom: homeIndicator),
        ),
        child: Builder(
          builder: (context) {
            layout = AppLayout.of(context);
            padding = layout.scrollPadding(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // Dock chrome: outer 12 + inner pads 16 + tab row 48 + breathing 8.
    const dockChrome = 12.0 + 16.0 + 48.0 + 8.0;
    expect(
      padding.bottom,
      closeTo(layout.pagePadding.bottom + dockChrome + homeIndicator, 0.01),
    );
    expect(padding.top, layout.pagePadding.top);
    expect(padding.left, layout.pagePadding.left);
  });
}
