import '../repositories/notification_repository.dart';

class SyncFcmToken {
  SyncFcmToken(this._repo);
  final NotificationRepository _repo;

  Future<void> call(String uid) => _repo.syncTokenForUser(uid);
}
