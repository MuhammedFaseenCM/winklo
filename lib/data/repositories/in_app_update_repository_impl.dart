import 'dart:async';

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
      return await _downloadFlexibleUpdate();
    } catch (_) {
      return InAppUpdateOutcome.unavailable;
    }
  }

  /// Play answers the start call once the download is done, the player said
  /// no, or an install error happened, but not when the download is
  /// cancelled from its notification; the install status says so instead.
  Future<InAppUpdateOutcome> _downloadFlexibleUpdate() async {
    final outcome = Completer<InAppUpdateOutcome>();
    void finish(InAppUpdateOutcome value) {
      if (!outcome.isCompleted) outcome.complete(value);
    }

    final statuses = _client.installStatuses.listen((status) {
      if (status == InstallStatus.canceled) {
        finish(InAppUpdateOutcome.declined);
      } else if (status == InstallStatus.failed) {
        finish(InAppUpdateOutcome.unavailable);
      }
    }, onError: (Object _) {});
    try {
      unawaited(
        _client.startFlexibleUpdate().then(
          (result) => finish(switch (result) {
            AppUpdateResult.success => InAppUpdateOutcome.downloaded,
            AppUpdateResult.userDeniedUpdate => InAppUpdateOutcome.declined,
            AppUpdateResult.inAppUpdateFailed => InAppUpdateOutcome.unavailable,
          }),
          onError: (Object _) => finish(InAppUpdateOutcome.unavailable),
        ),
      );
      return await outcome.future;
    } finally {
      await statuses.cancel();
    }
  }

  @override
  Future<bool> completeFlexibleUpdate() async {
    try {
      await _client.checkForUpdate();
    } catch (_) {
      return false;
    }
    // Play restarts the app to install; the plugin never answers this call.
    unawaited(_client.completeFlexibleUpdate().catchError((Object _) {}));
    return true;
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
