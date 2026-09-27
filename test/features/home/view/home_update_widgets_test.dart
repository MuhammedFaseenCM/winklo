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
