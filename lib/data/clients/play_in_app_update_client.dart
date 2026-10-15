import 'package:in_app_update/in_app_update.dart';

/// The calls [InAppUpdate] offers, as an object so tests can stand in for
/// Play.
class PlayInAppUpdateClient {
  const PlayInAppUpdateClient();

  Future<AppUpdateInfo> checkForUpdate() => InAppUpdate.checkForUpdate();

  Future<AppUpdateResult> startFlexibleUpdate() =>
      InAppUpdate.startFlexibleUpdate();

  Future<void> completeFlexibleUpdate() => InAppUpdate.completeFlexibleUpdate();

  Future<AppUpdateResult> performImmediateUpdate() =>
      InAppUpdate.performImmediateUpdate();
}
