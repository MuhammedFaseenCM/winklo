import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../domain/entities/recorded_open.dart';
import '../../domain/repositories/activity_repository.dart';
import '../clients/activity/guest_activity_client.dart';
import 'activity_install_id.dart';

/// The app's version and build, as an open records them.
typedef AppBuild = ({String version, int build});

Future<AppBuild> _platformBuild() async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, build: int.tryParse(info.buildNumber) ?? 0);
}

class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(
    this._prefs, {
    this._firestore,
    this._guestClient,
    Future<AppBuild> Function()? appBuild,
    this._random,
  }) : _loadAppBuild = appBuild ?? _platformBuild;

  static const _lastAtKey = 'activity_last_recorded_at_ms';
  static const _lastWhoKey = 'activity_last_recorded_key';
  static const _installIdKey = 'activity_install_id';

  /// The bounds the rules and the activity Worker put on a build number.
  static const _maxBuild = 10000000;

  final SharedPreferences _prefs;
  final FirebaseFirestore? _firestore;
  final GuestActivityClient? _guestClient;
  final Future<AppBuild> Function() _loadAppBuild;
  final Random? _random;
  Future<String>? _installId;
  AppBuild? _appBuild;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  @override
  RecordedOpen? lastRecorded() {
    final ms = _prefs.getInt(_lastAtKey);
    final key = _prefs.getString(_lastWhoKey);
    if (ms == null || key == null) return null;
    return RecordedOpen(
      at: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      key: key,
    );
  }

  @override
  Future<void> markRecorded(RecordedOpen open) async {
    await _prefs.setInt(_lastAtKey, open.at.toUtc().millisecondsSinceEpoch);
    await _prefs.setString(_lastWhoKey, open.key);
  }

  @override
  Future<String> installId() => _installId ??= _loadInstallId();

  Future<String> _loadInstallId() async {
    final stored = _prefs.getString(_installIdKey);
    if (stored != null && isInstallId(stored)) return stored;
    final id = newInstallId(_random);
    await _prefs.setString(_installIdKey, id);
    return id;
  }

  /// Read once per process. When it can't be read the open still counts, as
  /// version "unknown", and the next open tries again.
  Future<AppBuild> _build() async {
    final cached = _appBuild;
    if (cached != null) return cached;
    final AppBuild raw;
    try {
      raw = await _loadAppBuild();
    } catch (_) {
      return (version: 'unknown', build: 0);
    }
    return _appBuild = _bounded(raw);
  }

  /// What the rules and the Worker accept: 1–32 of `0-9A-Za-z.+-`, and a build
  /// of 0…10 000 000.
  static AppBuild _bounded(AppBuild raw) {
    final cleaned = raw.version.replaceAll(RegExp(r'[^0-9A-Za-z.+-]'), '');
    final version = cleaned.isEmpty
        ? 'unknown'
        : cleaned.substring(0, min(cleaned.length, 32));
    return (version: version, build: raw.build.clamp(0, _maxBuild).toInt());
  }

  @override
  Future<bool> recordOpen({
    required String uid,
    required String installId,
    required String dayId,
    required String platform,
    required DateTime at,
  }) async {
    final db = _db;
    if (db == null) return false;
    final app = await _build();
    final ref = db
        .collection('daily_activity')
        .doc(dayId)
        .collection('users')
        .doc(uid);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'uid': uid,
          'firstOpenAt': FieldValue.serverTimestamp(),
          'lastOpenAt': FieldValue.serverTimestamp(),
          'platform': platform,
          'opens': 1,
          'appVersion': app.version,
          'build': app.build,
          'installId': installId,
        });
      } else {
        await ref.update({
          'lastOpenAt': FieldValue.serverTimestamp(),
          'platform': platform,
          'opens': FieldValue.increment(1),
          'appVersion': app.version,
          'build': app.build,
          'installId': installId,
        });
      }
      return true;
    } catch (e, st) {
      debugPrint('Activity recordOpen failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  @override
  Future<bool> recordGuestOpen({
    required String installId,
    required String dayId,
    required String platform,
  }) async {
    final client = _guestClient;
    if (client == null) return false;
    final app = await _build();
    await client.recordOpen({
      'installId': installId,
      'dayId': dayId,
      'platform': platform,
      'appVersion': app.version,
      'build': app.build,
    });
    return true;
  }
}
