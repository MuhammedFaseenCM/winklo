import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/features/home/view/widgets/home_force_update_overlay.dart';
import 'package:winklo/features/home/view/widgets/home_update_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('soft banner shows update copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeUpdateBanner(
            currentLabel: '1.0.0+1',
            requiredLabel: '1.0.0+2',
            onUpdate: () {},
          ),
        ),
      ),
    );
    expect(find.text(AppStrings.updateAvailableTitle), findsOneWidget);
    expect(find.text(AppStrings.updateNow), findsOneWidget);
  });

  testWidgets('soft banner has a close button only when it can snooze', (
    tester,
  ) async {
    var snoozed = 0;
    Widget banner({VoidCallback? onSnooze}) => MaterialApp(
      home: Scaffold(
        body: HomeUpdateBanner(
          currentLabel: '',
          requiredLabel: '',
          onUpdate: () {},
          onSnooze: onSnooze,
        ),
      ),
    );

    await tester.pumpWidget(banner());
    expect(find.byTooltip(AppStrings.updateSnooze), findsNothing);

    await tester.pumpWidget(banner(onSnooze: () => snoozed++));
    await tester.tap(find.byTooltip(AppStrings.updateSnooze));
    expect(snoozed, 1);
  });

  testWidgets('soft banner button can be relabelled and disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeUpdateBanner(
            currentLabel: '',
            requiredLabel: '',
            onUpdate: null,
            updateLabel: AppStrings.updateDownloading,
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.updateDownloading), findsOneWidget);
    expect(find.text(AppStrings.updateNow), findsNothing);
  });

  testWidgets('force overlay blocks underlying button', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TextButton(
                onPressed: () => tapped = true,
                child: const Text('Play'),
              ),
              HomeForceUpdateOverlay(onUpdate: () async {}),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Play'), warnIfMissed: false);
    expect(tapped, isFalse);
    expect(find.text(AppStrings.updateRequiredTitle), findsOneWidget);
    expect(find.text(AppStrings.updateCantSkip), findsOneWidget);
  });
}
