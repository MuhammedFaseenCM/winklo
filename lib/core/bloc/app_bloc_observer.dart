import 'package:bloc/bloc.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../errors/client_error_reporter.dart';
import '../firebase/firebase_bootstrap.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    if (kDebugMode) {
      debugPrint('${bloc.runtimeType} $change');
    }
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint('${bloc.runtimeType} $error');
    } else if (FirebaseBootstrap.isReady) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        fatal: false,
        reason: bloc.runtimeType.toString(),
      );
      ClientErrorReporter.instance.reportBloc(
        error,
        stackTrace,
        blocType: bloc.runtimeType.toString(),
      );
    }
    super.onError(bloc, error, stackTrace);
  }
}
