import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/data/clients/play_in_app_update_client.dart';
import 'package:winklo/data/repositories/in_app_update_repository_impl.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';

class _MockClient extends Mock implements PlayInAppUpdateClient {}

AppUpdateInfo _info({
  UpdateAvailability availability = UpdateAvailability.updateAvailable,
  bool flexibleAllowed = true,
  bool immediateAllowed = true,
  InstallStatus installStatus = InstallStatus.unknown,
}) => AppUpdateInfo(
  updateAvailability: availability,
  immediateUpdateAllowed: immediateAllowed,
  immediateAllowedPreconditions: null,
  flexibleUpdateAllowed: flexibleAllowed,
  flexibleAllowedPreconditions: null,
  availableVersionCode: 20,
  installStatus: installStatus,
  packageName: 'com.winklo.faseencm',
  clientVersionStalenessDays: 1,
  updatePriority: 0,
);

void main() {
  late _MockClient client;
  late InAppUpdateRepositoryImpl repo;

  // What Play answers on a sideloaded or debug build.
  final notOwned = PlatformException(
    code: 'TASK_FAILURE',
    message: 'Install Error(-10): The app is not owned by any user',
  );

  setUp(() {
    client = _MockClient();
    repo = InAppUpdateRepositoryImpl(client: client);
    when(() => client.completeFlexibleUpdate()).thenAnswer((_) async {});
  });

  void check(AppUpdateInfo info) =>
      when(() => client.checkForUpdate()).thenAnswer((_) async => info);

  group('startFlexibleUpdate', () {
    test('a finished download is downloaded', () async {
      check(_info());
      when(
        () => client.startFlexibleUpdate(),
      ).thenAnswer((_) async => AppUpdateResult.success);

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.downloaded);
    });

    test('an update downloaded earlier skips the download', () async {
      check(_info(installStatus: InstallStatus.downloaded));

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.downloaded);
      verifyNever(() => client.startFlexibleUpdate());
    });

    test('is unavailable when Play has no update yet', () async {
      check(_info(availability: UpdateAvailability.updateNotAvailable));

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.unavailable);
      verifyNever(() => client.startFlexibleUpdate());
    });

    test('is unavailable when Play does not allow a flexible update', () async {
      check(_info(flexibleAllowed: false));

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.unavailable);
      verifyNever(() => client.startFlexibleUpdate());
    });

    test('the player saying no is declined', () async {
      check(_info());
      when(
        () => client.startFlexibleUpdate(),
      ).thenAnswer((_) async => AppUpdateResult.userDeniedUpdate);

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.declined);
    });

    test('a sideloaded or debug build is unavailable', () async {
      when(() => client.checkForUpdate()).thenThrow(notOwned);

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.unavailable);
    });

    test('a failed download is unavailable', () async {
      check(_info());
      when(
        () => client.startFlexibleUpdate(),
      ).thenAnswer((_) async => AppUpdateResult.inAppUpdateFailed);

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.unavailable);
    });

    test('a download error is unavailable', () async {
      check(_info());
      when(
        () => client.startFlexibleUpdate(),
      ).thenThrow(PlatformException(code: 'Error during installation'));

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.unavailable);
    });

    test('no plugin (tests, other platforms) is unavailable', () async {
      when(
        () => client.checkForUpdate(),
      ).thenThrow(MissingPluginException('no in_app_update'));

      expect(await repo.startFlexibleUpdate(), InAppUpdateOutcome.unavailable);
    });
  });

  group('performImmediateUpdate', () {
    test('accepted', () async {
      check(_info());
      when(
        () => client.performImmediateUpdate(),
      ).thenAnswer((_) async => AppUpdateResult.success);

      expect(await repo.performImmediateUpdate(), InAppUpdateOutcome.accepted);
    });

    test('declined', () async {
      check(_info());
      when(
        () => client.performImmediateUpdate(),
      ).thenAnswer((_) async => AppUpdateResult.userDeniedUpdate);

      expect(await repo.performImmediateUpdate(), InAppUpdateOutcome.declined);
    });

    test('is unavailable without an update in Play', () async {
      check(_info(availability: UpdateAvailability.updateNotAvailable));

      expect(
        await repo.performImmediateUpdate(),
        InAppUpdateOutcome.unavailable,
      );
      verifyNever(() => client.performImmediateUpdate());
    });

    test('is unavailable when Play does not allow it', () async {
      check(_info(immediateAllowed: false));

      expect(
        await repo.performImmediateUpdate(),
        InAppUpdateOutcome.unavailable,
      );
      verifyNever(() => client.performImmediateUpdate());
    });

    test('is unavailable on a sideloaded or debug build', () async {
      when(() => client.checkForUpdate()).thenThrow(notOwned);

      expect(
        await repo.performImmediateUpdate(),
        InAppUpdateOutcome.unavailable,
      );
    });

    test('a failed update is unavailable', () async {
      check(_info());
      when(
        () => client.performImmediateUpdate(),
      ).thenAnswer((_) async => AppUpdateResult.inAppUpdateFailed);

      expect(
        await repo.performImmediateUpdate(),
        InAppUpdateOutcome.unavailable,
      );
    });
  });

  group('hasDownloadedUpdate', () {
    test('is true once Play has the download', () async {
      check(_info(installStatus: InstallStatus.downloaded));

      expect(await repo.hasDownloadedUpdate(), isTrue);
    });

    test('is false otherwise', () async {
      check(_info(installStatus: InstallStatus.downloading));

      expect(await repo.hasDownloadedUpdate(), isFalse);
    });

    test('is false when Play cannot be asked', () async {
      when(() => client.checkForUpdate()).thenThrow(notOwned);

      expect(await repo.hasDownloadedUpdate(), isFalse);
    });
  });

  group('completeFlexibleUpdate', () {
    test('checks with Play first, then installs', () async {
      check(_info(installStatus: InstallStatus.downloaded));

      expect(await repo.completeFlexibleUpdate(), isTrue);

      verifyInOrder([
        () => client.checkForUpdate(),
        () => client.completeFlexibleUpdate(),
      ]);
    });

    test('is false when Play cannot install', () async {
      when(() => client.checkForUpdate()).thenThrow(notOwned);

      expect(await repo.completeFlexibleUpdate(), isFalse);
      verifyNever(() => client.completeFlexibleUpdate());
    });
  });
}
