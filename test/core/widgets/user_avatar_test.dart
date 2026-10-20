import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/user_avatar.dart';

void main() {
  testWidgets('shows initials when no photo or avatarId', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: UserAvatar(displayName: 'Ada', radius: 20)),
      ),
    );
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('draws a preset as its bundled critter, over photoUrl', (
    tester,
  ) async {
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
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('an unknown preset id falls back to initials', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: UserAvatar(displayName: 'Ada', avatarId: 'gone', radius: 20),
        ),
      ),
    );
    expect(find.text('A'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });
}
