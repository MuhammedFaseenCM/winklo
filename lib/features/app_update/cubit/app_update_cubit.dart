import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/entities/app_update_decision.dart';
import '../../../domain/repositories/app_update_repository.dart';
import '../../../domain/usecases/check_app_update.dart';
import 'app_update_state.dart';

class AppUpdateCubit extends Cubit<AppUpdateState> with WidgetsBindingObserver {
  AppUpdateCubit({
    required this.checkAppUpdate,
    required this.appUpdateRepository,
  }) : super(const AppUpdateState()) {
    WidgetsBinding.instance.addObserver(this);
  }

  final CheckAppUpdate checkAppUpdate;
  final AppUpdateRepository appUpdateRepository;

  Future<void> check() async {
    final decision = await checkAppUpdate();
    if (isClosed) return;
    emit(AppUpdateState(status: decision.status, storeUrl: decision.storeUrl));
  }

  Future<void> openStore() async {
    final url = state.storeUrl;
    if (url.isEmpty) return;
    await appUpdateRepository.openStore(url);
  }

  bool get isForced => state.status == AppUpdateStatus.forced;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      check();
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
