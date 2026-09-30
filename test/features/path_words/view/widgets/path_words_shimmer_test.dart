import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/app_shimmer.dart';
import 'package:winklo/features/path_words/view/widgets/path_words_shimmer.dart';

void main() {
  testWidgets('PathWordsShimmer builds a shimmer grid', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PathWordsShimmer())),
    );

    expect(find.byType(AppShimmer), findsOneWidget);
    expect(find.byType(AppShimmerBox), findsNWidgets(25));
  });
}
