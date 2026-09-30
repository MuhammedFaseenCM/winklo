import '../repositories/notification_repository.dart';

class ClearNotificationToken {
  ClearNotificationToken(this._repo);
  final NotificationRepository _repo;

  Future<void> call({String? uid}) => _repo.clearTokenOnSignOut(uid: uid);
}
