import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/user_avatar.dart';
import 'package:winklo/domain/avatars/avatar_catalog.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/features/profile/cubit/profile_cubit.dart';
import 'package:winklo/features/profile/view/widgets/avatar_edit_sheet.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockImagePicker extends Mock implements ImagePicker {}

/// Network presets use CachedNetworkImage + progress placeholders, so
/// [WidgetTester.pumpAndSettle] never completes. Advance a fixed duration.
Future<void> _pumpSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

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

  testWidgets('fits a short bottom sheet without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
                          create: (_) => ProfileCubit(
                            profileRepository: profile,
                            updateDisplayName: UpdateDisplayName(profile),
                            updateAvatar: UpdateAvatar(profile),
                            uid: user.uid,
                          ),
                          child: const SizedBox(
                            height: 420,
                            child: AvatarEditSheet(),
                          ),
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

    expect(find.text(AppStrings.profileEditAvatar), findsOneWidget);
    expect(find.text(AppStrings.profileChoosePhoto), findsOneWidget);
    expect(
      flutterErrors.where((e) => e.contains('overflowed')),
      isEmpty,
      reason: flutterErrors.join('\n'),
    );
  });

  testWidgets('shows a tile for each preset id', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: BlocProvider(
          create: (_) => ProfileCubit(
            profileRepository: profile,
            updateDisplayName: UpdateDisplayName(profile),
            updateAvatar: UpdateAvatar(profile),
            uid: user.uid,
          ),
          child: const Scaffold(body: AvatarEditSheet()),
        ),
      ),
    );
    await _pumpSheet(tester);

    expect(
      find.byType(UserAvatar),
      findsNWidgets(AvatarCatalog.presetIds.length),
    );
  });

  testWidgets('picks a resized, compressed photo', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picker = _MockImagePicker();
    when(
      () => picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).thenAnswer((_) async => null);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: BlocProvider(
          create: (_) => ProfileCubit(
            profileRepository: profile,
            updateDisplayName: UpdateDisplayName(profile),
            updateAvatar: UpdateAvatar(profile),
            uid: user.uid,
          ),
          child: Scaffold(body: AvatarEditSheet(imagePicker: picker)),
        ),
      ),
    );
    await _pumpSheet(tester);

    await tester.tap(find.text(AppStrings.profileChoosePhoto));
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
