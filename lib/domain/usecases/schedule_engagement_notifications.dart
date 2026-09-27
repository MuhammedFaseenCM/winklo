import '../repositories/notification_repository.dart';

class ScheduleEngagementNotifications {
  ScheduleEngagementNotifications(this._repo);
  final NotificationRepository _repo;

  Future<void> call({
    required bool zipClearedToday,
    required bool pathWordsClearedToday,
    required bool sudokuClearedToday,
    required String dailyReadyTitle,
    required String dailyReadyBody,
    required String streakAtRiskTitle,
    required String streakAtRiskBody,
  }) => _repo.refreshEngagementSchedules(
    zipClearedToday: zipClearedToday,
    pathWordsClearedToday: pathWordsClearedToday,
    sudokuClearedToday: sudokuClearedToday,
    dailyReadyTitle: dailyReadyTitle,
    dailyReadyBody: dailyReadyBody,
    streakAtRiskTitle: streakAtRiskTitle,
    streakAtRiskBody: streakAtRiskBody,
  );
}
