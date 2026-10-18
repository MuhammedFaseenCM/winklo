/// How a Play in-app update request ended.
enum InAppUpdateOutcome {
  /// A flexible update finished downloading; a restart installs it.
  downloaded,

  /// The player accepted an immediate update (Play restarts the app).
  accepted,

  /// The player said no in Play's dialog.
  declined,

  /// Play can't update in place: no update in Play yet, a sideloaded or
  /// debug build, no Play Store, or an error. Callers open the store page.
  unavailable,
}

/// Google Play's in-app updates.
abstract class InAppUpdateRepository {
  /// Whether an earlier flexible update is downloaded and waiting to install.
  Future<bool> hasDownloadedUpdate();

  /// Downloads the update in the background while the app stays usable.
  Future<InAppUpdateOutcome> startFlexibleUpdate();

  /// Installs a downloaded flexible update; Play restarts the app. False when
  /// it couldn't start.
  Future<bool> completeFlexibleUpdate();

  /// Play's full-screen update, for the forced update screen.
  Future<InAppUpdateOutcome> performImmediateUpdate();
}
