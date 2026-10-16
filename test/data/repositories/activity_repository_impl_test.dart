import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:winklo/core/firebase/firebase_bootstrap.dart';
import 'package:winklo/data/clients/activity/guest_activity_client.dart';
import 'package:winklo/data/repositories/activity_install_id.dart';
import 'package:winklo/data/repositories/activity_repository_impl.dart';
import 'package:winklo/domain/entities/recorded_open.dart';

class _FakeGuestClient implements GuestActivityClient {
  final sent = <Map<String, Object?>>[];
  Object? failWith;

  @override
  Future<void> recordOpen(Map<String, Object?> body) async {
    final failure = failWith;
    if (failure != null) throw failure;
    sent.add(body);
  }
}

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

Future<AppBuild> _build() async => (version: '1.1.0', build: 19);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('last recorded open', () {
    test('is null before the first one', () async {
      final repo = ActivityRepositoryImpl(await _prefs());
      expect(repo.lastRecorded(), isNull);
    });

    test('round-trips when and whose', () async {
      final repo = ActivityRepositoryImpl(await _prefs());
      final open = RecordedOpen(at: DateTime.utc(2026, 10, 5, 12), key: 'u:u1');
      await repo.markRecorded(open);
      expect(repo.lastRecorded(), open);
    });

    test('is null when an older build left only a time', () async {
      final repo = ActivityRepositoryImpl(
        await _prefs({'activity_last_recorded_at_ms': 1759665600000}),
      );
      expect(repo.lastRecorded(), isNull);
    });
  });

  group('install ID', () {
    test('is made once and kept', () async {
      final prefs = await _prefs();
      final first = await ActivityRepositoryImpl(prefs).installId();
      expect(isInstallId(first), isTrue);
      expect(await ActivityRepositoryImpl(prefs).installId(), first);
    });

    test('two calls at once agree', () async {
      final repo = ActivityRepositoryImpl(await _prefs());
      final ids = await Future.wait([repo.installId(), repo.installId()]);
      expect(ids[0], ids[1]);
    });

    test('a stored value that is not an install ID is replaced', () async {
      final repo = ActivityRepositoryImpl(
        await _prefs({'activity_install_id': 'garbage'}),
      );
      expect(isInstallId(await repo.installId()), isTrue);
    });
  });

  group('guest opens', () {
    test('are skipped without a Worker', () async {
      final repo = ActivityRepositoryImpl(await _prefs(), appBuild: _build);
      final wrote = await repo.recordGuestOpen(
        installId: 'i',
        dayId: '2026-10-17',
        platform: 'android',
      );
      expect(wrote, isFalse);
    });

    test('send the open with the app version and build', () async {
      final client = _FakeGuestClient();
      final repo = ActivityRepositoryImpl(
        await _prefs(),
        guestClient: client,
        appBuild: _build,
      );
      final wrote = await repo.recordGuestOpen(
        installId: 'i',
        dayId: '2026-10-17',
        platform: 'android',
      );
      expect(wrote, isTrue);
      expect(client.sent, [
        {
          'installId': 'i',
          'dayId': '2026-10-17',
          'platform': 'android',
          'appVersion': '1.1.0',
          'build': 19,
        },
      ]);
    });

    test('bound the version and build to what the Worker accepts', () async {
      final client = _FakeGuestClient();
      final repo = ActivityRepositoryImpl(
        await _prefs(),
        guestClient: client,
        appBuild: () async => (version: ' 1.1.0 beta ', build: -3),
      );
      await repo.recordGuestOpen(installId: 'i', dayId: 'd', platform: 'ios');
      expect(client.sent.single['appVersion'], '1.1.0beta');
      expect(client.sent.single['build'], 0);
    });

    test('fall back to unknown when the version cannot be read', () async {
      final client = _FakeGuestClient();
      final repo = ActivityRepositoryImpl(
        await _prefs(),
        guestClient: client,
        appBuild: () async => throw Exception('no plugin'),
      );
      await repo.recordGuestOpen(installId: 'i', dayId: 'd', platform: 'ios');
      expect(client.sent.single['appVersion'], 'unknown');
      expect(client.sent.single['build'], 0);
    });

    test('pass a Worker failure on', () async {
      final client = _FakeGuestClient()
        ..failWith = const GuestActivityUnavailable('HTTP 503');
      final repo = ActivityRepositoryImpl(
        await _prefs(),
        guestClient: client,
        appBuild: _build,
      );
      await expectLater(
        repo.recordGuestOpen(installId: 'i', dayId: 'd', platform: 'ios'),
        throwsA(isA<GuestActivityUnavailable>()),
      );
    });
  });

  group('signed-in opens when Firebase is not ready', () {
    late bool wasReady;

    setUp(() {
      wasReady = FirebaseBootstrap.isReady;
      FirebaseBootstrap.isReady = false;
    });

    tearDown(() {
      FirebaseBootstrap.isReady = wasReady;
    });

    test('are skipped', () async {
      final repo = ActivityRepositoryImpl(await _prefs(), appBuild: _build);
      final wrote = await repo.recordOpen(
        uid: 'u1',
        installId: 'i',
        dayId: '2026-10-05',
        platform: 'android',
        at: DateTime(2026, 10, 5),
      );
      expect(wrote, isFalse);
    });
  });
}
