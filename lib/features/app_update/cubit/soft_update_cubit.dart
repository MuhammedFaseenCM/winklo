import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/app_update_repository.dart';
import '../../../domain/repositories/in_app_update_repository.dart';
import '../../../domain/repositories/update_banner_snooze_repository.dart';
import 'soft_update_state.dart';

/// Home's soft update banner: closing it for a day, and updating through
/// Play in place (a flexible update, then "Restart to update"), with the
/// store page as the fallback.
class SoftUpdateCubit extends Cubit<SoftUpdateState> {
  SoftUpdateCubit({
    required this.inAppUpdates,
    required this.appUpdateRepository,
    required UpdateBannerSnoozeRepository snooze,
    this.analytics,
    DateTime Function()? clock,
  }) : _snooze = snooze,
       _clock = clock ?? DateTime.now,
       super(SoftUpdateState(snoozedUntil: snooze.snoozedUntil()));

  /// How long the close button hides the banner.
  static const snoozeFor = Duration(hours: 24);

  final InAppUpdateRepository inAppUpdates;
  final AppUpdateRepository appUpdateRepository;
  final AnalyticsRepository? analytics;
  final UpdateBannerSnoozeRepository _snooze;
  final DateTime Function() _clock;

  /// Whether the banner is closed right now.
  bool get isHidden {
    final until = state.snoozedUntil;
    return until != null && _clock().isBefore(until);
  }

  /// Offers the restart when an earlier download is waiting to install.
  Future<void> checkDownloaded() async {
    if (state.phase != SoftUpdatePhase.idle) return;
    final downloaded = await inAppUpdates.hasDownloadedUpdate();
    if (isClosed || !downloaded || state.phase != SoftUpdatePhase.idle) return;
    emit(state.copyWith(phase: SoftUpdatePhase.readyToInstall));
  }

  Future<void> snooze() async {
    final until = _clock().add(snoozeFor);
    await _snooze.snoozeUntil(until);
    if (isClosed) return;
    emit(state.copyWith(snoozedUntil: until));
  }

  /// The banner's button: downloads in place, installs a finished download,
  /// or opens [storeUrl] when Play can't update in place.
  Future<void> update(String storeUrl) async {
    switch (state.phase) {
      case SoftUpdatePhase.downloading:
        return;
      case SoftUpdatePhase.readyToInstall:
        await inAppUpdates.completeFlexibleUpdate();
        return;
      case SoftUpdatePhase.idle:
        break;
    }
    unawaited(analytics?.logUpdatePromptAccepted(forced: false));
    emit(state.copyWith(phase: SoftUpdatePhase.downloading));
    final outcome = await inAppUpdates.startFlexibleUpdate();
    if (isClosed) return;
    switch (outcome) {
      case InAppUpdateOutcome.downloaded:
        emit(state.copyWith(phase: SoftUpdatePhase.readyToInstall));
      case InAppUpdateOutcome.accepted:
      case InAppUpdateOutcome.declined:
        emit(state.copyWith(phase: SoftUpdatePhase.idle));
      case InAppUpdateOutcome.unavailable:
        emit(state.copyWith(phase: SoftUpdatePhase.idle));
        if (storeUrl.isNotEmpty) {
          await appUpdateRepository.openStore(storeUrl);
        }
    }
  }
}
