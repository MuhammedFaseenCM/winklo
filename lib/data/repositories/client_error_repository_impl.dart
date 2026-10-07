import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/client_error_report.dart';
import '../../domain/repositories/client_error_repository.dart';

const _maxMessage = 500;
const _maxCause = 500;
const _maxStack = 4000;
const _maxCode = 80;
const _maxScreen = 120;
const _maxFunction = 160;

/// Builds Firestore fields for a client error (without `createdAt`).
@visibleForTesting
Map<String, Object?> buildClientErrorFields({
  required ClientErrorReport report,
  required String appVersion,
  required String buildNumber,
  required String platform,
  String? locale,
}) {
  final payload = <String, Object?>{
    'severity': _clip(report.severity, 16),
    'source': _clip(report.source, 16),
    'code': _clip(report.code, _maxCode),
    'message': _clip(report.message, _maxMessage),
    'appVersion': appVersion,
    'buildNumber': buildNumber,
    'platform': platform,
  };

  final cause = report.cause;
  if (cause != null && cause.isNotEmpty) {
    payload['cause'] = _clip(cause, _maxCause);
  }
  final stack = report.stack;
  if (stack != null && stack.isNotEmpty) {
    payload['stack'] = _clip(stack, _maxStack);
  }
  final screen = report.screen;
  if (screen != null && screen.isNotEmpty) {
    payload['screen'] = _clip(screen, _maxScreen);
  }
  final function = report.function;
  if (function != null && function.isNotEmpty) {
    payload['function'] = _clip(function, _maxFunction);
  }
  final uid = report.uid;
  if (uid != null && uid.isNotEmpty) {
    payload['uid'] = uid;
  }
  if (locale != null && locale.isNotEmpty) {
    payload['locale'] = _clip(locale, 32);
  }
  return payload;
}

String _clip(String value, int max) {
  final trimmed = value.trim();
  if (trimmed.length <= max) return trimmed;
  return trimmed.substring(0, max);
}

class ClientErrorRepositoryImpl implements ClientErrorRepository {
  ClientErrorRepositoryImpl({
    this.firestore,
    this.writeTimeout = const Duration(seconds: 10),
  });

  final FirebaseFirestore? firestore;

  /// Bounds the wait for the server ack of one report.
  final Duration writeTimeout;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return firestore ?? FirebaseFirestore.instance;
  }

  @override
  Future<void> report(ClientErrorReport report) async {
    final db = _db;
    if (db == null) return;

    try {
      final info = await PackageInfo.fromPlatform();
      final payload = buildClientErrorFields(
        report: report,
        appVersion: info.version,
        buildNumber: info.buildNumber,
        platform: defaultTargetPlatform.name,
        locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      );
      payload['createdAt'] = FieldValue.serverTimestamp();
      // Offline, a write future only completes on server ack (the doc stays
      // queued by persistence); never let telemetry block its caller.
      await db.collection('client_errors').add(payload).timeout(writeTimeout);
    } catch (e, st) {
      debugPrint('ClientErrorRepository report failed: $e');
      debugPrint('$st');
    }
  }
}
