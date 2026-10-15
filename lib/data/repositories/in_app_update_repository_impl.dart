import 'package:in_app_update/in_app_update.dart';
import 'package:winklo/data/clients/play_in_app_update_client.dart';
import 'package:winklo/domain/repositories/in_app_update_repository.dart';

/// Play's in-app updates through `in_app_update`.
///
/// Every call asks Play first: the plugin needs a fresh `checkForUpdate`
/// before it can start, finish or install anything. Anything that goes wrong
/// (a sideloaded or debug build, no Play Store, no plugin on this platform)
/// is [InAppUpdateOutcome.unavailable], so callers fall back to the store.
class InAppUpdateRepositoryImpl implements InAppUpdateRepository {
  InAppUpdateRepositoryImpl({PlayInAppUpdateClient? client})
    : _client = client ?? const PlayInAppUpdateClient();

  final PlayInAppUpdateClient _client;

  @override
  Future<bool> hasDownloadedUpdate() async {
    try {
      final info = await _client.checkForUpdate();
      return info.installStatus == InstallStatus.downloaded;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<InAppUpdateOutcome> startFlexibleUpdate() async {
    try {
      final info = await _client.checkForUpdate();
      if (info.installStatus == InstallStatus.downloaded) {
        return InAppUpdateOutcome.downloaded;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.flexibleUpdateAllowed) {
        return InAppUpdateOutcome.unavailable;
      }
      // Completes once the download has finished, or the player said no.
      return switch (await _client.startFlexibleUpdate()) {
        AppUpdateResult.success => InAppUpdateOutcome.downloaded,
        AppUpdateResult.userDeniedUpdate => InAppUpdateOutcome.declined,
        AppUpdateResult.inAppUpdateFailed => InAppUpdateOutcome.unavailable,
      };
    } catch (_) {
      return InAppUpdateOutcome.unavailable;
    }
  }

  @override
  Future<bool> completeFlexibleUpdate() async {
    try {
      await _client.checkForUpdate();
      await _client.completeFlexibleUpdate();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<InAppUpdateOutcome> performImmediateUpdate() async {
    try {
      final info = await _client.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.immediateUpdateAllowed) {
        return InAppUpdateOutcome.unavailable;
      }
      return switch (await _client.performImmediateUpdate()) {
        AppUpdateResult.success => InAppUpdateOutcome.accepted,
        AppUpdateResult.userDeniedUpdate => InAppUpdateOutcome.declined,
        AppUpdateResult.inAppUpdateFailed => InAppUpdateOutcome.unavailable,
      };
    } catch (_) {
      return InAppUpdateOutcome.unavailable;
    }
  }
}
