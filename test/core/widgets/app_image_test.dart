import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/app_image.dart';

void main() {
  group('AppImage.looksLikeSvg', () {
    test('detects .svg ignoring case and query', () {
      expect(AppImage.looksLikeSvg('icons/Logo.SVG'), isTrue);
      expect(AppImage.looksLikeSvg('https://cdn.ex/a.svg?x=1'), isTrue);
      expect(AppImage.looksLikeSvg('photo.jpg'), isFalse);
    });
  });

  testWidgets('asset svg uses SvgPicture', (tester) async {
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"></svg>';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImage.memory(
            Uint8List.fromList(svg.codeUnits),
            width: 10,
            height: 10,
            isSvg: true,
          ),
        ),
      ),
    );
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('empty network url shows errorWidget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppImage.network('', errorWidget: const Text('bad')),
        ),
      ),
    );
    expect(find.text('bad'), findsOneWidget);
  });
}
