import '../repositories/notification_repository.dart';

class InitializeNotifications {
  InitializeNotifications(this._repo);
  final NotificationRepository _repo;

  Future<void> call() => _repo.initialize();
}
