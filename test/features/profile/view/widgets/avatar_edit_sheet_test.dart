import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/features/profile/cubit/profile_cubit.dart';
import 'package:winklo/features/profile/view/widgets/avatar_edit_sheet.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

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
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.profileEditAvatar), findsOneWidget);
    expect(find.text(AppStrings.profileChoosePhoto), findsOneWidget);
    expect(
      flutterErrors.where((e) => e.contains('overflowed')),
      isEmpty,
      reason: flutterErrors.join('\n'),
    );
  });

  testWidgets('loads all preset assets without image errors', (tester) async {
    final imageErrors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      imageErrors.add(details.exceptionAsString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

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
    await tester.pumpAndSettle();

    expect(
      imageErrors.where((e) => e.contains('Could not decompress image')),
      isEmpty,
      reason: imageErrors.join('\n'),
    );
    expect(find.byType(Image), findsNWidgets(6));
  });
}
