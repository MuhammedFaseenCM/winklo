import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/client_error_report.dart';
import '../../domain/repositories/client_error_repository.dart';
import '../../domain/usecases/report_client_error.dart';
import '../firebase/firebase_bootstrap.dart';
import 'client_error_context.dart';

typedef ClientErrorUidProvider = String? Function();

/// Fire-and-forget client error writer with session throttle / dedupe.
class ClientErrorReporter {
  ClientErrorReporter({
    required ClientErrorRepository repository,
    ClientErrorUidProvider? uidProvider,
    this.maxWritesPerSession = 20,
    this.dedupeCooldown = const Duration(seconds: 60),
  }) : _report = ReportClientError(repository),
       _uidProvider = uidProvider ?? (() => null);

  final ReportClientError _report;
  final ClientErrorUidProvider _uidProvider;
  final int maxWritesPerSession;
  final Duration dedupeCooldown;

  static ClientErrorReporter? _instance;

  /// When true, allows reporting even under `kDebugMode` (tests only).
  @visibleForTesting
  static bool allowInDebug = false;

  /// Installed from app bootstrap; safe no-op until then.
  static ClientErrorReporter get instance =>
      _instance ?? ClientErrorReporter._noop();

  static void install(ClientErrorReporter reporter) {
    _instance = reporter;
  }

  ClientErrorReporter._noop()
    : _report = ReportClientError(_NoopClientErrorRepository()),
      _uidProvider = (() => null),
      maxWritesPerSession = 0,
      dedupeCooldown = Duration.zero;

  int _writesThisSession = 0;
  final Map<String, DateTime> _recentKeys = {};

  void reportHandled({
    required String code,
    required String message,
    String? cause,
    String? stack,
    String? function,
    String? screen,
    String severity = 'error',
  }) {
    _enqueue(
      ClientErrorReport(
        severity: severity,
        source: 'handled',
        code: code,
        message: message,
        cause: cause,
        stack: stack,
        screen: screen ?? ClientErrorContext.currentScreen,
        function: function,
        uid: _uidProvider(),
      ),
    );
  }

  void reportFlutter(Object error, StackTrace stack, {bool fatal = true}) {
    _enqueue(
      ClientErrorReport(
        severity: fatal ? 'fatal' : 'error',
        source: 'flutter',
        code: 'flutter_error',
        message: error.toString(),
        cause: error.runtimeType.toString(),
        stack: stack.toString(),
        screen: ClientErrorContext.currentScreen,
        function: null,
        uid: _uidProvider(),
      ),
    );
  }

  void reportPlatform(Object error, StackTrace stack, {bool fatal = true}) {
    _enqueue(
      ClientErrorReport(
        severity: fatal ? 'fatal' : 'error',
        source: 'platform',
        code: 'platform_error',
        message: error.toString(),
        cause: error.runtimeType.toString(),
        stack: stack.toString(),
        screen: ClientErrorContext.currentScreen,
        function: null,
        uid: _uidProvider(),
      ),
    );
  }

  void reportBloc(Object error, StackTrace stack, {required String blocType}) {
    _enqueue(
      ClientErrorReport(
        severity: 'error',
        source: 'bloc',
        code: 'bloc_error',
        message: error.toString(),
        cause: error.runtimeType.toString(),
        stack: stack.toString(),
        screen: ClientErrorContext.currentScreen,
        function: blocType,
        uid: _uidProvider(),
      ),
    );
  }

  void _enqueue(ClientErrorReport report) {
    if ((kDebugMode && !allowInDebug) || !FirebaseBootstrap.isReady) return;
    if (_writesThisSession >= maxWritesPerSession) return;

    final key = '${report.code}|${report.message}|${report.function ?? ''}';
    final now = DateTime.now();
    final last = _recentKeys[key];
    if (last != null && now.difference(last) < dedupeCooldown) return;

    _recentKeys[key] = now;
    _writesThisSession += 1;
    unawaited(_report(report));
  }
}

class _NoopClientErrorRepository implements ClientErrorRepository {
  @override
  Future<void> report(ClientErrorReport report) async {}
}
