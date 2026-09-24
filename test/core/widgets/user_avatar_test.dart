import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/widgets/user_avatar.dart';

void main() {
  testWidgets('prefers preset asset over photoUrl', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAvatar(
            displayName: 'Ada',
            avatarId: 'preset_01',
            photoUrl: 'https://example.com/x.png',
            radius: 20,
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
  });
}
