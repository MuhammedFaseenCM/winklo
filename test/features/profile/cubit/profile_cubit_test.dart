import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/failures.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/profile_repository.dart';
import 'package:winklo/domain/usecases/update_avatar.dart';
import 'package:winklo/domain/usecases/update_display_name.dart';
import 'package:winklo/features/profile/cubit/profile_cubit.dart';
import 'package:winklo/features/profile/cubit/profile_state.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAnalytics extends Mock implements AnalyticsRepository {}

void main() {
  const original = AppUser(uid: 'u1', displayName: 'Ada');
  const updated = AppUser(uid: 'u1', displayName: 'Grace');

  late _MockProfileRepository repo;
  late StreamController<AppUser?> profileController;

  setUp(() {
    repo = _MockProfileRepository();
    profileController = StreamController<AppUser?>.broadcast();
    when(
      () => repo.watchProfile(any()),
    ).thenAnswer((_) => profileController.stream);
  });

  tearDown(() async {
    await profileController.close();
  });

  ProfileCubit buildCubit({String? uid = 'u1'}) => ProfileCubit(
    profileRepository: repo,
    updateDisplayName: UpdateDisplayName(repo),
    updateAvatar: UpdateAvatar(repo),
    uid: uid,
  );

  group('analytics', () {
    late _MockAnalytics analytics;

    setUp(() {
      analytics = _MockAnalytics();
      when(() => analytics.logProfileNameChanged()).thenAnswer((_) async {});
      when(
        () => analytics.logProfileAvatarChanged(source: any(named: 'source')),
      ).thenAnswer((_) async {});
    });

    ProfileCubit cubitWithAnalytics() => ProfileCubit(
      profileRepository: repo,
      updateDisplayName: UpdateDisplayName(repo),
      updateAvatar: UpdateAvatar(repo),
      uid: 'u1',
      analytics: analytics,
    );

    test('a saved name logs profile_name_changed', () async {
      when(
        () => repo.updateDisplayName('Grace'),
      ).thenAnswer((_) async => updated);
      final cubit = cubitWithAnalytics()..setNameDraft('Grace');

      await cubit.saveName();

      verify(() => analytics.logProfileNameChanged()).called(1);
      await cubit.close();
    });

    test('a failed name save logs nothing', () async {
      when(
        () => repo.updateDisplayName('Grace'),
      ).thenThrow(const Failure('nope'));
      final cubit = cubitWithAnalytics()..setNameDraft('Grace');

      await cubit.saveName();

      verifyNever(() => analytics.logProfileNameChanged());
      await cubit.close();
    });

    test('a preset avatar logs source preset', () async {
      when(
        () => repo.updateAvatarPreset(any()),
      ).thenAnswer((_) async => original);
      final cubit = cubitWithAnalytics();

      await cubit.selectPreset('preset_02');

      verify(
        () => analytics.logProfileAvatarChanged(source: 'preset'),
      ).called(1);
      await cubit.close();
    });
  });

  blocTest<ProfileCubit, ProfileState>(
    'saveName success emits idle with updated profile',
    build: buildCubit,
    seed: () => const ProfileState(nameDraft: 'Grace', profile: original),
    setUp: () {
      when(
        () => repo.updateDisplayName('Grace'),
      ).thenAnswer((_) async => updated);
    },
    act: (cubit) => cubit.saveName(),
    expect: () => [
      const ProfileState(
        status: ProfileStatus.saving,
        nameDraft: 'Grace',
        profile: original,
      ),
      const ProfileState(
        status: ProfileStatus.idle,
        nameDraft: 'Grace',
        profile: updated,
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'saveName empty draft fails validation and does not call repo',
    build: buildCubit,
    seed: () => const ProfileState(nameDraft: '   '),
    act: (cubit) => cubit.saveName(),
    expect: () => [
      ProfileState(
        status: ProfileStatus.failure,
        nameDraft: '   ',
        error: AppStrings.profileNameEmpty,
        failureKind: ProfileFailureKind.name,
      ),
    ],
    verify: (_) {
      verifyNever(() => repo.updateDisplayName(any()));
    },
  );

  blocTest<ProfileCubit, ProfileState>(
    'selectPreset failure from repo emits failure status',
    build: buildCubit,
    setUp: () {
      when(
        () => repo.updateAvatarPreset('preset_02'),
      ).thenThrow(const Failure('offline'));
    },
    act: (cubit) => cubit.selectPreset('preset_02'),
    expect: () => [
      const ProfileState(status: ProfileStatus.saving),
      const ProfileState(
        status: ProfileStatus.failure,
        error: 'offline',
        failureKind: ProfileFailureKind.avatar,
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'profile snapshot seeds empty name draft',
    build: buildCubit,
    act: (cubit) => profileController.add(original),
    expect: () => [const ProfileState(profile: original, nameDraft: 'Ada')],
  );

  blocTest<ProfileCubit, ProfileState>(
    'profile snapshot preserves user name draft',
    build: buildCubit,
    act: (cubit) async {
      cubit.setNameDraft('Typed first');
      profileController.add(original);
    },
    expect: () => [
      const ProfileState(nameDraft: 'Typed first', nameDraftTouched: true),
      const ProfileState(
        nameDraft: 'Typed first',
        nameDraftTouched: true,
        profile: original,
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'refresh emits refreshing then idle with profile',
    build: buildCubit,
    seed: () => const ProfileState(profile: original),
    setUp: () {
      when(() => repo.getProfile('u1')).thenAnswer((_) async => updated);
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      const ProfileState(status: ProfileStatus.refreshing, profile: original),
      const ProfileState(
        status: ProfileStatus.idle,
        profile: updated,
        nameDraft: 'Grace',
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'refresh failure emits failure and keeps prior profile',
    build: buildCubit,
    seed: () => const ProfileState(profile: original),
    setUp: () {
      when(() => repo.getProfile('u1')).thenThrow(const Failure('offline'));
    },
    act: (cubit) => cubit.refresh(),
    expect: () => [
      const ProfileState(status: ProfileStatus.refreshing, profile: original),
      const ProfileState(
        status: ProfileStatus.failure,
        profile: original,
        error: 'offline',
        failureKind: ProfileFailureKind.watchProfile,
      ),
    ],
  );

  blocTest<ProfileCubit, ProfileState>(
    'profile snapshot preserves cleared name draft',
    build: buildCubit,
    act: (cubit) async {
      cubit.setNameDraft('');
      profileController.add(original);
    },
    expect: () => [
      const ProfileState(nameDraft: '', nameDraftTouched: true),
      const ProfileState(
        nameDraft: '',
        nameDraftTouched: true,
        profile: original,
      ),
    ],
  );
}
