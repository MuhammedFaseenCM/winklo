import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/leaderboard_entry.dart';
import 'package:winklo/domain/entities/leaderboard_period.dart';
import 'package:winklo/domain/game_ids.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_podium.dart';
import 'package:winklo/features/leaderboard/view/widgets/leaderboard_table.dart';
import 'package:winklo/features/profile/cubit/profile_cubit.dart';
import 'package:winklo/features/profile/view/widgets/avatar_edit_sheet.dart';

import '../../../helpers/screenshot.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

const _user = AppUser(
  uid: 'u1',
  displayName: 'Anu Krishnan',
  avatarId: 'preset_09',
);

/// The avatar sheet and a board of critters: nothing overflows, and with
/// `WINKLO_SCREENSHOTS=1`, PNGs in build/screenshots/.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) => Completer<Object?>().future,
        );
    await loadScreenshotFonts();
  });

  const boundary = Key('avatar_shot');

  Future<List<FlutterErrorDetails>> pumpFrame(
    WidgetTester tester,
    Size size,
    Widget child,
  ) async {
    final overflows = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) overflows.add(details);
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: buildAppTheme(),
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    );
    return overflows;
  }

  /// SVGs decode off the test clock, so give them real time.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> shot(
    WidgetTester tester,
    List<FlutterErrorDetails> overflows,
    String name,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    expect(overflows, isEmpty, reason: '$name: ${overflows.firstOrNull}');
    await saveScreenshot(tester, find.byKey(boundary), name);
  }

  Future<List<FlutterErrorDetails>> pumpSheet(
    WidgetTester tester,
    Size size,
  ) async {
    final profile = _MockProfileRepository();
    when(
      () => profile.watchProfile(_user.uid),
    ).thenAnswer((_) => Stream<AppUser?>.value(_user));
    final overflows = await pumpFrame(
      tester,
      size,
      Scaffold(
        backgroundColor: ZipColors.mist,
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: ZipColors.wall,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => BlocProvider(
                  create: (_) => ProfileCubit(
                    profileRepository: profile,
                    updateDisplayName: UpdateDisplayName(profile),
                    updateAvatar: UpdateAvatar(profile),
                    uid: _user.uid,
                  ),
                  child: const AvatarEditSheet(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    return overflows;
  }

  for (final size in const [Size(392, 850), Size(360, 740), Size(320, 568)]) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('Avatar sheet, $tag', (tester) async {
      final overflows = await pumpSheet(tester, size);
      expect(find.text(AppStrings.profileAvatarHint), findsOneWidget);
      await shot(tester, overflows, 'avatar_sheet_$tag');
    });
  }

  testWidgets('Avatar sheet, Malayalam, 360x740', (tester) async {
    AppStrings.use('ml');
    addTearDown(() => AppStrings.use('en'));
    final overflows = await pumpSheet(tester, const Size(360, 740));
    await shot(tester, overflows, 'avatar_sheet_ml_360x740');
  });

  testWidgets('A board of critters, 392x850', (tester) async {
    final ids = AvatarCatalog.presetIds.toList();
    const names = [
      'Meera', 'Rahul', 'Anu Krishnan', 'Faiz', 'Devika', 'Arjun', //
      'Nila', 'Sanjay', 'Leya', 'Kiran', 'Hari', 'Zoya',
    ];
    final entries = [
      for (var i = 0; i < ids.length; i++)
        LeaderboardEntry(
          uid: 'p$i',
          displayName: names[i],
          avatarId: ids[i],
          timeSeconds: 38 + i * 4,
          updatedAt: DateTime(2026, 10, 21),
          rank: i + 1,
        ),
    ];
    final overflows = await pumpFrame(
      tester,
      const Size(392, 850),
      Scaffold(
        backgroundColor: ZipColors.mist,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LeaderboardPodium(
                  entries: entries.take(3).toList(),
                  period: LeaderboardPeriod.daily,
                  gameId: GameIds.zip,
                  currentUid: 'p2',
                  onTap: (_) {},
                ),
                const SizedBox(height: 16),
                const LeaderboardTableHeader(period: LeaderboardPeriod.daily),
                for (final entry in entries.skip(3))
                  LeaderboardTableRow(
                    entry: entry,
                    period: LeaderboardPeriod.daily,
                    gameId: GameIds.zip,
                    isYou: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await shot(tester, overflows, 'avatar_board_392x850');
  });
}
