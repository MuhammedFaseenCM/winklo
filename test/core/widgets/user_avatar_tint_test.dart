import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/user_avatar.dart';

void main() {
  test('a seed always gets the same hue from the palette', () {
    expect(avatarTintFor('uid-123'), avatarTintFor('uid-123'));
    expect(avatarTintPalette, contains(avatarTintFor('uid-123')));
  });

  test('different players spread across the palette', () {
    final hues = {for (var i = 0; i < 40; i++) avatarTintFor('player$i')};
    expect(hues.length, greaterThanOrEqualTo(5));
  });

  testWidgets('initials take the tint; no seed keeps the grey', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Row(
          children: [
            const UserAvatar(displayName: 'Ada', tintSeed: 'u1'),
            const UserAvatar(displayName: 'Bo'),
          ],
        ),
      ),
    );
    final avatars = tester
        .widgetList<CircleAvatar>(find.byType(CircleAvatar))
        .toList();
    final tint = avatarTintFor('u1');
    expect(avatars[0].backgroundColor, tint.withValues(alpha: 0.18));
    expect(tester.widget<Text>(find.text('A')).style?.color, tint);
    expect(avatars[1].backgroundColor, ZipColors.mistDeep);
  });
}
