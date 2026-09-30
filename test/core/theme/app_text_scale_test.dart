import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_text_scale.dart';

void main() {
  group('clampAppTextScaler', () {
    test('always uses noScaling regardless of system scale', () {
      expect(
        identical(clampAppTextScaler(TextScaler.linear(1)), kAppTextScaler),
        isTrue,
      );
      expect(
        identical(clampAppTextScaler(TextScaler.linear(2)), kAppTextScaler),
        isTrue,
      );
      expect(
        identical(clampAppTextScaler(TextScaler.linear(0.5)), kAppTextScaler),
        isTrue,
      );
      expect(kAppTextScaler.scale(10), 10);
    });
  });

  testWidgets('AppTextScale ignores large system textScaler', (tester) async {
    late TextScaler effective;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: AppTextScale(
          child: Builder(
            builder: (context) {
              effective = MediaQuery.textScalerOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(effective.scale(10), 10);
  });
}
