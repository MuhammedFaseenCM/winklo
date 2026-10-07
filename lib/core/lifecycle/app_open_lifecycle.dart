import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/record_app_open.dart';

/// Firestore `daily_activity` rules allow only `ios`, `android`, and `other`.
/// [TargetPlatform.iOS] lowercases to `ios`; desktop and fuchsia become `other`.
String appOpenPlatformLabel([TargetPlatform? platform]) {
  final name = (platform ?? defaultTargetPlatform).name.toLowerCase();
  if (name == 'ios' || name == 'android') return name;
  return 'other';
}

class AppOpenLifecycle with WidgetsBindingObserver {
  AppOpenLifecycle(this._recordAppOpen, this._authRepository);

  final RecordAppOpen _recordAppOpen;
  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _authSub;
  String? _lastUid;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Seed before subscribe so the current session is not treated as a new
    // sign-in. A later null → uid transition still pings (auth restore / login).
    _lastUid = _authRepository.currentUser?.uid;
    _authSub = _authRepository.authStateChanges().listen(_onAuth);
    unawaited(_ping());
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _authSub;
    _authSub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ping());
    }
  }

  void _onAuth(AppUser? user) {
    final uid = user?.uid;
    final signedIn = uid != null && _lastUid == null;
    _lastUid = uid;
    if (signedIn) {
      unawaited(_ping());
    }
  }

  Future<void> _ping() {
    return _recordAppOpen(platform: appOpenPlatformLabel());
  }
}
