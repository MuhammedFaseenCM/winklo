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
  AppOpenLifecycle(
    this._recordAppOpen,
    this._authRepository, {
    this.authWait = const Duration(seconds: 5),
  });

  final RecordAppOpen _recordAppOpen;
  final AuthRepository _authRepository;

  /// How long the first ping waits for an auth event. The auth stream can stay
  /// silent (its profile listener may fail before the first emit), and without
  /// this no open would be recorded for the whole session.
  final Duration authWait;
  Timer? _authTimer;
  StreamSubscription<AppUser?>? _authSub;
  String? _lastUid;
  bool _started = false;

  /// Whether Firebase has said who is signed in. Until then a ping would see
  /// a restoring session as a guest, so the first one waits for it.
  bool _authKnown = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    // Seed before subscribe so the current session is not treated as a new
    // sign-in. A later null → uid transition still pings (auth restore / login).
    _lastUid = _authRepository.currentUser?.uid;
    _authSub = _authRepository.authStateChanges().listen(_onAuth);
    _authTimer = Timer(authWait, _onAuthTimeout);
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _authTimer?.cancel();
    _authTimer = null;
    final subscription = _authSub;
    _authSub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    _started = false;
    _authKnown = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _authKnown) {
      unawaited(_ping());
    }
  }

  void _onAuthTimeout() {
    _authTimer = null;
    if (_authKnown) return;
    _authKnown = true;
    _lastUid = _authRepository.currentUser?.uid;
    unawaited(_ping());
  }

  void _onAuth(AppUser? user) {
    _authTimer?.cancel();
    _authTimer = null;
    final uid = user?.uid;
    final first = !_authKnown;
    _authKnown = true;
    final signedIn = uid != null && _lastUid == null;
    _lastUid = uid;
    if (first || signedIn) {
      unawaited(_ping());
    }
  }

  Future<void> _ping() {
    return _recordAppOpen(platform: appOpenPlatformLabel());
  }
}
