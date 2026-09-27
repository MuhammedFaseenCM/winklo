import '../../../domain/entities/app_update_decision.dart';

class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.none,
    this.storeUrl = '',
  });

  final AppUpdateStatus status;
  final String storeUrl;

  AppUpdateState copyWith({AppUpdateStatus? status, String? storeUrl}) {
    return AppUpdateState(
      status: status ?? this.status,
      storeUrl: storeUrl ?? this.storeUrl,
    );
  }
}
