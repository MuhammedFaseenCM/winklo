import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/core/lifecycle/app_open_lifecycle.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/record_app_open.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockRecord extends Mock implements RecordAppOpen {}

const _user = AppUser(uid: 'u1', displayName: 'A');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuth auth;
  late _MockRecord record;
  late StreamController<AppUser?> authEvents;
  late AppOpenLifecycle lifecycle;
  late int pings;

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    auth = _MockAuth();
    record = _MockRecord();
    authEvents = StreamController<AppUser?>.broadcast();
    pings = 0;
    when(() => auth.authStateChanges()).thenAnswer((_) => authEvents.stream);
    when(() => auth.currentUser).thenReturn(null);
    when(() => record(platform: any(named: 'platform'))).thenAnswer((_) async {
      pings++;
    });
    lifecycle = AppOpenLifecycle(record, auth);
  });

  tearDown(() async {
    lifecycle.dispose();
    await authEvents.close();
  });

  test('the cold-start ping waits for the first auth event', () async {
    lifecycle.start();
    await settle();
    expect(pings, 0);

    authEvents.add(null);
    await settle();
    expect(pings, 1);
  });

  test('a resume before auth is known waits; after, it pings', () async {
    lifecycle.start();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(pings, 0);

    authEvents.add(null);
    await settle();
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await settle();
    expect(pings, 2);
  });

  test('a restored session is one ping, not a guest one first', () async {
    lifecycle.start();
    authEvents.add(_user);
    await settle();
    expect(pings, 1);
  });

  test('signing in later pings again; the same user again does not', () async {
    lifecycle.start();
    authEvents.add(null);
    await settle();
    authEvents.add(_user);
    await settle();
    authEvents.add(_user);
    await settle();
    expect(pings, 2);
  });

  test('a session known at start pings once on the first event', () async {
    when(() => auth.currentUser).thenReturn(_user);
    lifecycle.start();
    authEvents.add(_user);
    await settle();
    expect(pings, 1);
  });
}
