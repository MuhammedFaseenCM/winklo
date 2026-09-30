import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../data/clients/remote_config_client.dart';
import '../../firebase_options.dart';
import '../errors/client_error_reporter.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool isReady = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      isReady = true;
      debugPrint('Firebase initialized');
      await RemoteConfigClient.instance.initialize(
        defaults: RemoteConfigClient.defaultValues(),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(minutes: 15),
      );
      await _configureCrashlytics();
    } catch (e, st) {
      isReady = false;
      debugPrint('Firebase unavailable, using local seed assets: $e');
      debugPrint('$st');
    }
  }

  static Future<void> _configureCrashlytics() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
    } catch (e, st) {
      debugPrint('Crashlytics setup failed: $e');
      debugPrint('$st');
    }
  }

  /// Wire Flutter / platform error handlers when Firebase is ready (release).
  static void installErrorHandlers() {
    if (!isReady || kDebugMode) return;
    FlutterError.onError = (details) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      ClientErrorReporter.instance.reportFlutter(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      ClientErrorReporter.instance.reportPlatform(error, stack);
      return true;
    };
  }
}
