import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/features/profile/cubit/profile_cubit.dart';
import 'package:winklo/features/profile/view/widgets/avatar_edit_sheet.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockImagePicker extends Mock implements ImagePicker {}

/// Critter SVGs load asynchronously and a save shows a spinner, so
/// [WidgetTester.pumpAndSettle] may never complete. Advance a fixed duration.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _tile(String avatarId) =>
    find.byKey(ValueKey('avatar-preset-$avatarId'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const user = AppUser(uid: 'u1', displayName: 'Ada', avatarId: 'preset_01');

  late _MockProfileRepository profile;

  setUp(() {
    profile = _MockProfileRepository();
    when(
      () => profile.watchProfile('u1'),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
  });

  ProfileCubit buildCubit() => ProfileCubit(
    profileRepository: profile,
    updateDisplayName: UpdateDisplayName(profile),
    updateAvatar: UpdateAvatar(profile),
    uid: user.uid,
  );

  Future<void> pumpInScaffold(
    WidgetTester tester, {
    ImagePicker? picker,
  }) async {
    tester.view.physicalSize = const Size(392, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: BlocProvider(
          create: (_) => buildCubit(),
          child: Scaffold(body: AvatarEditSheet(imagePicker: picker)),
        ),
      ),
    );
    await _pumpSheet(tester);
  }

  for (final size in const [Size(320, 568), Size(360, 640), Size(390, 844)]) {
    testWidgets('fits a ${size.width.toInt()}×${size.height.toInt()} phone '
        'without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final flutterErrors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        flutterErrors.add(details.exceptionAsString());
        previous?.call(details);
      };
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: ZipColors.wall,
                        builder: (_) {
                          return BlocProvider(
                            create: (_) => buildCubit(),
                            child: const AvatarEditSheet(),
                          );
                        },
                      );
                    },
                    child: const Text('open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await _pumpSheet(tester);

      expect(find.text(AppStrings.profileAvatarHint), findsOneWidget);
      expect(find.text(AppStrings.profileAvatarPhoto), findsOneWidget);
      expect(
        flutterErrors.where((e) => e.contains('overflowed')),
        isEmpty,
        reason: flutterErrors.join('\n'),
      );
    });
  }

  testWidgets('shows a tile for each preset id', (tester) async {
    await pumpInScaffold(tester);

    for (final id in AvatarCatalog.presetIds) {
      expect(_tile(id), findsOneWidget, reason: id);
    }
  });

  testWidgets('the selected critter is marked for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpInScaffold(tester);

    expect(
      tester.getSemantics(_tile('preset_01')),
      isSemantics(label: 'Fox', isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(_tile('preset_09')),
      isSemantics(label: 'Tiger', isButton: true, isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('tapping a critter saves it; tiles wait while it saves', (
    tester,
  ) async {
    final save = Completer<AppUser>();
    when(
      () => profile.updateAvatarPreset('preset_09'),
    ).thenAnswer((_) => save.future);
    await pumpInScaffold(tester);

    await tester.tap(_tile('preset_09'));
    await tester.pump();

    verify(() => profile.updateAvatarPreset('preset_09')).called(1);
    expect(
      find.descendant(
        of: _tile('preset_09'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    await tester.tap(_tile('preset_12'));
    await tester.pump();
    verifyNever(() => profile.updateAvatarPreset('preset_12'));

    save.complete(
      const AppUser(uid: 'u1', displayName: 'Ada', avatarId: 'preset_09'),
    );
    await _pumpSheet(tester);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.getSemantics(_tile('preset_09')),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('tapping the current critter does not save again', (
    tester,
  ) async {
    await pumpInScaffold(tester);

    await tester.tap(_tile('preset_01'));
    await tester.pump();

    verifyNever(() => profile.updateAvatarPreset(any()));
  });

  testWidgets('the Photo pill picks a resized, compressed photo', (
    tester,
  ) async {
    final picker = _MockImagePicker();
    when(
      () => picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => null);
    await pumpInScaffold(tester, picker: picker);

    await tester.tap(find.text(AppStrings.profileAvatarPhoto));
    await tester.pump();

    verify(
      () => picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: avatarPickMaxSide,
        maxHeight: avatarPickMaxSide,
        imageQuality: avatarPickQuality,
      ),
    ).called(1);
  });
}
