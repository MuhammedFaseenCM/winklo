# App opens B: the app and the rules — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app records every open, signed in or guest. Signed-in records also carry the open count, app version, build and install ID. The Firestore rules accept the new fields and keep guest docs admin-read-only.

**Architecture:** `RecordAppOpen` picks the identity (`u:<uid>` or `g:<installId>`) and throttles per identity and day. Signed-in opens write Firestore directly, as before. Guest opens go through `HttpGuestActivityClient` to the `winklo-activity` Worker (plan A). `ActivityRepositoryImpl` owns the install ID, the app version and the prefs. `AppOpenLifecycle` makes its first ping on the first auth event, so a restoring session is never recorded as a guest.

**Tech Stack:** Flutter/Dart, cloud_firestore, shared_preferences, package_info_plus, http, mocktail. Rules tests use vitest and `@firebase/rules-unit-testing` against the Firestore emulator.

Spec: `docs/superpowers/specs/2026-10-17-app-opens-tracking-design.md`. Plan A (`workers/activity`) must be done first: Task 6's pins test reads `workers/activity/src/open.ts`.

**Repo rules (from CLAUDE.md and memory):**
- `lib/domain/` imports no Flutter.
- Run `dart format` **only on the files you touched**. Never on `lib/` or `test/` as a whole: that rewrites about 11 unrelated files.
- No `build_runner` here (nothing touched uses freezed).
- If `pubspec.lock` changes, restore it with `git checkout pubspec.lock`.

---

## File structure

| File | Responsibility |
|------|----------------|
| `lib/data/repositories/activity_install_id.dart` (new) | Install ID pattern, check and generator |
| `lib/core/config/activity_config.dart` (new) | Worker base URL (`ACTIVITY_BASE_URL`) |
| `lib/data/clients/activity/guest_activity_client.dart` (new) | Client interface + `GuestActivityUnavailable` |
| `lib/data/clients/activity/http_guest_activity_client.dart` (new) | `POST {base}/v1/open` |
| `lib/domain/entities/recorded_open.dart` (new) | Last recorded open: when and whose |
| `lib/domain/repositories/activity_repository.dart` | New interface |
| `lib/domain/usecases/record_app_open.dart` | Identity choice + identity/day-aware throttle |
| `lib/data/repositories/activity_repository_impl.dart` | Prefs, install ID, app build, new fields, guest path |
| `lib/core/lifecycle/app_open_lifecycle.dart` | First ping on the first auth event |
| `lib/core/di/app_repositories.dart` | Wire the guest client |
| `firestore/firestore.rules` | New optional fields; guests subcollection |
| `firestore/rules_test/activity.test.ts` (new) | Rules tests |
| `test/firestore/activity_pins_test.dart` (new) | One install ID pattern and platform list across app, rules and Worker |
| `FIREBASE.md`, `README.md`, `docs/privacy/index.html` | Docs |

---

### Task 1: Install ID

**Files:**
- Create: `lib/data/repositories/activity_install_id.dart`
- Test: `test/data/repositories/activity_install_id_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/activity_install_id.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value;

  @override
  double nextDouble() => 0;

  @override
  bool nextBool() => false;
}

void main() {
  test('makes lowercase UUID v4 ids', () {
    for (var i = 0; i < 200; i++) {
      expect(isInstallId(newInstallId()), isTrue);
    }
  });

  test('sets the version and variant bits whatever the random bytes', () {
    expect(
      newInstallId(_FixedRandom(0xff)),
      'ffffffff-ffff-4fff-bfff-ffffffffffff',
    );
    expect(
      newInstallId(_FixedRandom(0)),
      '00000000-0000-4000-8000-000000000000',
    );
  });

  test('refuses other shapes', () {
    expect(isInstallId(''), isFalse);
    expect(isInstallId('not-an-id'), isFalse);
    expect(isInstallId(newInstallId().toUpperCase()), isFalse);
    expect(isInstallId('3f2b8c1e-9a4d-1e7f-b123-0c9d8e7f6a5b'), isFalse);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/data/repositories/activity_install_id_test.dart`
Expected: FAIL, the import doesn't exist.

- [ ] **Step 3: Implement**

`lib/data/repositories/activity_install_id.dart`:

```dart
import 'dart:math';

/// A lowercase UUID v4, the shape of an install ID. The same pattern is in
/// firestore/firestore.rules and workers/activity/src/open.ts;
/// test/firestore/activity_pins_test.dart keeps the three in step.
const installIdPattern =
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

final _installId = RegExp(installIdPattern);

bool isInstallId(String value) => _installId.hasMatch(value);

/// A fresh random install ID.
String newInstallId([Random? random]) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/data/repositories/activity_install_id_test.dart`
Expected: 3 passed.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/data/repositories/activity_install_id.dart test/data/repositories/activity_install_id_test.dart
git add lib/data/repositories/activity_install_id.dart test/data/repositories/activity_install_id_test.dart
git commit -m "feat(activity): install ID for guest app opens"
```

---

### Task 2: Guest activity client

**Files:**
- Create: `lib/core/config/activity_config.dart`
- Create: `lib/data/clients/activity/guest_activity_client.dart`
- Create: `lib/data/clients/activity/http_guest_activity_client.dart`
- Test: `test/data/clients/activity/http_guest_activity_client_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:winklo/data/clients/activity/guest_activity_client.dart';
import 'package:winklo/data/clients/activity/http_guest_activity_client.dart';

void main() {
  HttpGuestActivityClient clientFor(
    Future<http.Response> Function(http.Request request) handler, {
    String baseUrl = 'https://activity.example/',
  }) => HttpGuestActivityClient(
    baseUrl: baseUrl,
    httpClient: MockClient(handler),
  );

  const body = {
    'installId': '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b',
    'dayId': '2026-10-17',
    'platform': 'android',
    'appVersion': '1.1.0',
    'build': 19,
  };

  test('posts the open as JSON to /v1/open', () async {
    late http.Request sent;
    final client = clientFor((request) async {
      sent = request;
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    await client.recordOpen(body);

    expect(sent.method, 'POST');
    expect(sent.url.toString(), 'https://activity.example/v1/open');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), body);
  });

  test('a refusal, a 5xx or an odd reply is unavailable', () async {
    for (final reply in [
      http.Response(jsonEncode({'error': 'bad_request'}), 400),
      http.Response(jsonEncode({'error': 'rate_limited'}), 429),
      http.Response('down', 503),
      http.Response('<html>', 200),
    ]) {
      final client = clientFor((_) async => reply);
      await expectLater(
        client.recordOpen(body),
        throwsA(isA<GuestActivityUnavailable>()),
      );
    }
  });

  test('a network error is unavailable', () async {
    final client = clientFor((_) async => throw http.ClientException('off'));
    await expectLater(
      client.recordOpen(body),
      throwsA(isA<GuestActivityUnavailable>()),
    );
  });

  test('an empty base URL is unavailable without a request', () async {
    var called = false;
    final client = clientFor((_) async {
      called = true;
      return http.Response('{}', 200);
    }, baseUrl: '  ');
    await expectLater(
      client.recordOpen(body),
      throwsA(isA<GuestActivityUnavailable>()),
    );
    expect(called, isFalse);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/data/clients/activity/http_guest_activity_client_test.dart`
Expected: FAIL, imports don't exist.

- [ ] **Step 3: Implement**

`lib/core/config/activity_config.dart`:

```dart
abstract final class ActivityConfig {
  /// The activity Worker (`workers/activity`), which records guests' app
  /// opens. Override with `--dart-define=ACTIVITY_BASE_URL=…` for staging or
  /// a local Worker; an empty value leaves guest opens unrecorded.
  static const String baseUrl = String.fromEnvironment(
    'ACTIVITY_BASE_URL',
    defaultValue: 'https://winklo-activity.winklo.workers.dev',
  );

  static bool get isConfigured => baseUrl.trim().isNotEmpty;
}
```

`lib/data/clients/activity/guest_activity_client.dart`:

```dart
/// Posts a guest's (signed-out) app open to the activity Worker
/// (`workers/activity`, `POST /v1/open`).
abstract class GuestActivityClient {
  /// Sends one open [body]. Throws [GuestActivityUnavailable] when the Worker
  /// didn't record it: a network error, a timeout, a refusal or a 5xx.
  Future<void> recordOpen(Map<String, Object?> body);
}

/// The Worker didn't record the open; the next open tries again.
class GuestActivityUnavailable implements Exception {
  const GuestActivityUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'GuestActivityUnavailable($reason)';
}
```

`lib/data/clients/activity/http_guest_activity_client.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'guest_activity_client.dart';

class HttpGuestActivityClient implements GuestActivityClient {
  HttpGuestActivityClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  final Duration timeout;

  @override
  Future<void> recordOpen(Map<String, Object?> body) async {
    final root = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (root.isEmpty) {
      throw const GuestActivityUnavailable('not configured');
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('$root/v1/open'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const GuestActivityUnavailable('timeout');
    } catch (e) {
      throw GuestActivityUnavailable('network: $e');
    }

    if (response.statusCode != 200 || _decode(response.body)?['ok'] != true) {
      throw GuestActivityUnavailable('HTTP ${response.statusCode}');
    }
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/data/clients/activity/http_guest_activity_client_test.dart`
Expected: 4 passed.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/config/activity_config.dart lib/data/clients/activity test/data/clients/activity
git add lib/core/config/activity_config.dart lib/data/clients/activity test/data/clients/activity
git commit -m "feat(activity): client for the activity Worker"
```

---

### Task 3: Repository and use case (identity-aware throttle, guests, new fields)

The interface change breaks both the impl and the use case, so all three move in one task.

**Files:**
- Create: `lib/domain/entities/recorded_open.dart`
- Modify: `lib/domain/repositories/activity_repository.dart` (whole file)
- Modify: `lib/domain/usecases/record_app_open.dart` (whole file)
- Modify: `lib/data/repositories/activity_repository_impl.dart` (whole file)
- Test: `test/domain/usecases/record_app_open_test.dart` (rewrite)
- Test: `test/data/repositories/activity_repository_impl_test.dart` (rewrite)

- [ ] **Step 1: Write the use case test (replace the whole file)**

`test/domain/usecases/record_app_open_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/entities/recorded_open.dart';
import 'package:winklo/domain/repositories/activity_repository.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/record_app_open.dart';

class _MockAuth extends Mock implements AuthRepository {}

class _MockActivity extends Mock implements ActivityRepository {}

class _MockAnalytics extends Mock implements AnalyticsRepository {}

const _install = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const _user = AppUser(uid: 'u1', displayName: 'A');

void main() {
  late _MockAuth auth;
  late _MockActivity activity;
  late _MockAnalytics analytics;
  late RecordAppOpen usecase;

  setUpAll(() {
    registerFallbackValue(RecordedOpen(at: DateTime(2026), key: ''));
  });

  setUp(() {
    auth = _MockAuth();
    activity = _MockActivity();
    analytics = _MockAnalytics();
    usecase = RecordAppOpen(auth, activity, analytics);
    when(() => activity.installId()).thenAnswer((_) async => _install);
    when(() => activity.lastRecorded()).thenReturn(null);
    when(() => activity.markRecorded(any())).thenAnswer((_) async {});
    when(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => analytics.logAppOpen(platform: any(named: 'platform')),
    ).thenAnswer((_) async {});
  });

  void verifyNothingWritten() {
    verifyNever(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    );
    verifyNever(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    );
    verifyNever(() => activity.markRecorded(any()));
  }

  test('records a signed-in open with the install ID', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 5, 12);

    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        installId: _install,
        dayId: '2026-10-05',
        platform: 'android',
        at: now,
      ),
    ).called(1);
    verify(
      () => activity.markRecorded(RecordedOpen(at: now, key: 'u:u1')),
    ).called(1);
    verify(() => analytics.logAppOpen(platform: 'android')).called(1);
  });

  test('records a guest open through the guest path', () async {
    when(() => auth.currentUser).thenReturn(null);
    final now = DateTime(2026, 10, 5, 12);

    await usecase(now: now, platform: 'ios');

    verify(
      () => activity.recordGuestOpen(
        installId: _install,
        dayId: '2026-10-05',
        platform: 'ios',
      ),
    ).called(1);
    verify(
      () => activity.markRecorded(RecordedOpen(at: now, key: 'g:$_install')),
    ).called(1);
    verify(() => analytics.logAppOpen(platform: 'ios')).called(1);
  });

  test('skips the same identity within 5 minutes on the same day', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 5, 12);
    when(() => activity.lastRecorded()).thenReturn(
      RecordedOpen(at: now.subtract(const Duration(minutes: 2)), key: 'u:u1'),
    );

    await usecase(now: now, platform: 'android');

    verifyNothingWritten();
    verifyNever(() => analytics.logAppOpen(platform: any(named: 'platform')));
  });

  test('a sign-in right after a guest open is recorded', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 5, 12);
    when(() => activity.lastRecorded()).thenReturn(
      RecordedOpen(
        at: now.subtract(const Duration(minutes: 1)),
        key: 'g:$_install',
      ),
    );

    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        installId: _install,
        dayId: '2026-10-05',
        platform: 'android',
        at: now,
      ),
    ).called(1);
  });

  test('an open just past midnight counts for the new day', () async {
    when(() => auth.currentUser).thenReturn(_user);
    final now = DateTime(2026, 10, 6, 0, 1);
    when(() => activity.lastRecorded()).thenReturn(
      RecordedOpen(at: DateTime(2026, 10, 5, 23, 58), key: 'u:u1'),
    );

    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        installId: _install,
        dayId: '2026-10-06',
        platform: 'android',
        at: now,
      ),
    ).called(1);
  });

  test('does not throttle or log when the write was skipped', () async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    ).thenAnswer((_) async => false);

    await usecase(now: DateTime(2026, 10, 5, 12), platform: 'ios');

    verifyNever(() => activity.markRecorded(any()));
    verifyNever(() => analytics.logAppOpen(platform: any(named: 'platform')));
  });

  test('a failed write is swallowed and not throttled', () async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => activity.recordGuestOpen(
        installId: any(named: 'installId'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
      ),
    ).thenThrow(Exception('offline'));

    await usecase(now: DateTime(2026, 10, 5, 12), platform: 'ios');

    verifyNever(() => activity.markRecorded(any()));
  });
}
```

- [ ] **Step 2: Write the repository test (replace the whole file)**

`test/data/repositories/activity_repository_impl_test.dart`:

```dart
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
```

- [ ] **Step 3: Run both to see them fail**

Run: `flutter test test/domain/usecases/record_app_open_test.dart test/data/repositories/activity_repository_impl_test.dart`
Expected: compile errors (`RecordedOpen`, `recordGuestOpen`, `AppBuild` are not defined).

- [ ] **Step 4: Implement the entity and interface**

`lib/domain/entities/recorded_open.dart`:

```dart
/// The last app open this install wrote, and whose it was: `u:<uid>` for a
/// signed-in player, `g:<installId>` for a guest.
class RecordedOpen {
  const RecordedOpen({required this.at, required this.key});

  final DateTime at;
  final String key;

  @override
  bool operator ==(Object other) =>
      other is RecordedOpen && other.at.isAtSameMomentAs(at) && other.key == key;

  @override
  int get hashCode => Object.hash(at.millisecondsSinceEpoch, key);
}
```

`lib/domain/repositories/activity_repository.dart`:

```dart
import '../entities/recorded_open.dart';

abstract class ActivityRepository {
  /// The last recorded open, or null before the first one (or when an older
  /// build recorded it without saying whose).
  RecordedOpen? lastRecorded();

  Future<void> markRecorded(RecordedOpen open);

  /// This install's ID: a random UUID v4, made on first use and kept.
  Future<String> installId();

  /// Upserts the signed-in player's day doc. Returns `false` when skipped
  /// (e.g. Firebase not ready) so callers do not advance throttle /
  /// analytics. Throws on write failure after an attempt.
  Future<bool> recordOpen({
    required String uid,
    required String installId,
    required String dayId,
    required String platform,
    required DateTime at,
  });

  /// Records a guest's open through the activity Worker. Returns `false` when
  /// skipped (no Worker configured). Throws when the Worker didn't record it.
  Future<bool> recordGuestOpen({
    required String installId,
    required String dayId,
    required String platform,
  });
}
```

- [ ] **Step 5: Implement the use case**

`lib/domain/usecases/record_app_open.dart`:

```dart
import '../entities/leaderboard_period.dart';
import '../entities/recorded_open.dart';
import '../repositories/activity_repository.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/auth_repository.dart';

/// Records that the app was opened: the signed-in player's day doc, or the
/// guest's through the activity Worker.
class RecordAppOpen {
  RecordAppOpen(
    this._auth,
    this._activity,
    this._analytics, {
    this.throttle = const Duration(minutes: 5),
  });

  final AuthRepository _auth;
  final ActivityRepository _activity;
  final AnalyticsRepository _analytics;
  final Duration throttle;

  Future<void> call({DateTime? now, String? platform}) async {
    final at = now ?? DateTime.now();
    final dayId = leaderboardDayId(at);
    final resolvedPlatform = platform ?? 'other';
    try {
      final installId = await _activity.installId();
      final user = _auth.currentUser;
      final key = user == null ? 'g:$installId' : 'u:${user.uid}';
      // Skipped only for the same person on the same day: a sign-in right
      // after a guest open, or the first open past midnight, still counts.
      final last = _activity.lastRecorded();
      if (last != null &&
          last.key == key &&
          leaderboardDayId(last.at) == dayId &&
          at.difference(last.at) < throttle) {
        return;
      }

      final wrote = user == null
          ? await _activity.recordGuestOpen(
              installId: installId,
              dayId: dayId,
              platform: resolvedPlatform,
            )
          : await _activity.recordOpen(
              uid: user.uid,
              installId: installId,
              dayId: dayId,
              platform: resolvedPlatform,
              at: at,
            );
      // Skip throttle + FA when nothing was written (retry on next ping).
      if (!wrote) return;
      await _activity.markRecorded(RecordedOpen(at: at, key: key));
      await _analytics.logAppOpen(platform: resolvedPlatform);
    } catch (_) {
      // Best-effort: never block the app.
    }
  }
}
```

- [ ] **Step 6: Implement the repository**

`lib/data/repositories/activity_repository_impl.dart`:

```dart
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
    FirebaseFirestore? firestore,
    GuestActivityClient? guestClient,
    Future<AppBuild> Function()? appBuild,
    Random? random,
  }) : _firestore = firestore,
       _guestClient = guestClient,
       _loadAppBuild = appBuild ?? _platformBuild,
       _random = random;

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
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/domain/usecases/record_app_open_test.dart test/data/repositories/activity_repository_impl_test.dart`
Expected: all pass.

Run: `flutter analyze lib/domain lib/data test/domain/usecases test/data/repositories`
Expected: no new issues. Before you start, record the issue count on a clean checkout (`flutter analyze`) and compare against it.

- [ ] **Step 8: Format and commit**

```bash
dart format lib/domain/entities/recorded_open.dart lib/domain/repositories/activity_repository.dart lib/domain/usecases/record_app_open.dart lib/data/repositories/activity_repository_impl.dart test/domain/usecases/record_app_open_test.dart test/data/repositories/activity_repository_impl_test.dart
git add lib/domain/entities/recorded_open.dart lib/domain/repositories/activity_repository.dart lib/domain/usecases/record_app_open.dart lib/data/repositories/activity_repository_impl.dart test/domain/usecases/record_app_open_test.dart test/data/repositories/activity_repository_impl_test.dart
git commit -m "feat(activity): record guest opens, open counts and app versions"
```

---

### Task 4: First ping waits for auth

**Files:**
- Modify: `lib/core/lifecycle/app_open_lifecycle.dart`
- Test: `test/core/lifecycle/app_open_lifecycle_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
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
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/core/lifecycle/app_open_lifecycle_test.dart`
Expected: FAIL. "the cold-start ping waits…" sees 1 ping before any auth event.

- [ ] **Step 3: Implement**

Replace the class body in `lib/core/lifecycle/app_open_lifecycle.dart` (keep `appOpenPlatformLabel` and the imports as they are):

```dart
class AppOpenLifecycle with WidgetsBindingObserver {
  AppOpenLifecycle(this._recordAppOpen, this._authRepository);

  final RecordAppOpen _recordAppOpen;
  final AuthRepository _authRepository;
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
    _authKnown = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _authKnown) {
      unawaited(_ping());
    }
  }

  void _onAuth(AppUser? user) {
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
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/core/lifecycle/app_open_lifecycle_test.dart`
Expected: 5 passed.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/lifecycle/app_open_lifecycle.dart test/core/lifecycle/app_open_lifecycle_test.dart
git add lib/core/lifecycle/app_open_lifecycle.dart test/core/lifecycle/app_open_lifecycle_test.dart
git commit -m "fix(activity): first app-open ping waits for auth, so no phantom guest"
```

---

### Task 5: Wire the guest client

**Files:**
- Modify: `lib/core/di/app_repositories.dart`: the `RepositoryProvider<ActivityRepository>` entry (about line 194) and the imports

- [ ] **Step 1: Change the provider**

Add these imports, keeping the file's `package:winklo/...` style:

```dart
import 'package:winklo/core/config/activity_config.dart';
import 'package:winklo/data/clients/activity/http_guest_activity_client.dart';
```

Replace the provider:

```dart
    RepositoryProvider<ActivityRepository>(
      create: (context) => ActivityRepositoryImpl(
        context.read<SharedPreferences>(),
        guestClient: ActivityConfig.isConfigured
            ? HttpGuestActivityClient(baseUrl: ActivityConfig.baseUrl)
            : null,
      ),
    ),
```

- [ ] **Step 2: Analyze and run the DI tests**

Run: `flutter analyze lib/core/di && flutter test test/core`
Expected: no new issues; tests pass.

- [ ] **Step 3: Format and commit**

```bash
dart format lib/core/di/app_repositories.dart
git add lib/core/di/app_repositories.dart
git commit -m "feat(activity): send guest opens to the activity Worker"
```

---

### Task 6: Firestore rules, rules tests and pins

**Files:**
- Modify: `firestore/firestore.rules`: `validActivityCreate` / `validActivityUpdate` (about lines 659–677) and the `daily_activity` match (about line 679)
- Create: `firestore/rules_test/activity.test.ts`
- Create: `test/firestore/activity_pins_test.dart`

- [ ] **Step 1: Start the emulator** (skip if `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/` already prints 200)

```bash
JAVA="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java"
("$JAVA" -jar ~/.cache/firebase/emulators/cloud-firestore-emulator-v1.22.0.jar --host 127.0.0.1 --port 8080 > /tmp/firestore-emu.log 2>&1 &)
```

- [ ] **Step 2: Write the failing rules test**

`firestore/rules_test/activity.test.ts`:

```ts
import { assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDocs,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { rulesEnv } from './helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await rulesEnv('demo-winklo-activity');
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function db(uid: string | null, admin = false): Firestore {
  if (!uid) return env.unauthenticatedContext().firestore() as unknown as Firestore;
  return env.authenticatedContext(uid, admin ? { admin: true } : {}).firestore() as unknown as Firestore;
}

const DAY = '2026-10-17';
const INSTALL = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const userPath = (uid: string) => `daily_activity/${DAY}/users/${uid}`;

/** What 1.0.0+16 writes on a first open (activity_repository_impl.dart before this change). */
function oldCreate(uid: string) {
  return { uid, firstOpenAt: serverTimestamp(), lastOpenAt: serverTimestamp(), platform: 'android' };
}

/** What this build writes on a first open. */
function newCreate(uid: string) {
  return { ...oldCreate(uid), opens: 1, appVersion: '1.1.0', build: 19, installId: INSTALL };
}

/** What this build writes on a later open that day. */
function newUpdate() {
  return {
    lastOpenAt: serverTimestamp(),
    platform: 'android',
    opens: increment(1),
    appVersion: '1.1.0',
    build: 19,
    installId: INSTALL,
  };
}

describe('daily_activity users', () => {
  it('takes the old shape and the new one from the owner', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), userPath('u1')), oldCreate('u1')));
    await assertSucceeds(setDoc(doc(db('u2'), userPath('u2')), newCreate('u2')));
  });

  it('refuses a create that is not the first open', async () => {
    await assertFails(setDoc(doc(db('u1'), userPath('u1')), { ...newCreate('u1'), opens: 2 }));
  });

  it.each([
    ['an uppercase install id', { installId: INSTALL.toUpperCase() }],
    ['a non-v4 install id', { installId: '3f2b8c1e-9a4d-1e7f-b123-0c9d8e7f6a5b' }],
    ['a 33-character version', { appVersion: '1'.repeat(33) }],
    ['an empty version', { appVersion: '' }],
    ['a string build', { build: '19' }],
    ['a negative build', { build: -1 }],
    ['an unknown key', { extra: true }],
  ])('refuses %s', async (_name, patch) => {
    await assertFails(setDoc(doc(db('u1'), userPath('u1')), { ...newCreate('u1'), ...patch }));
  });

  it('refuses writes to someone else’s doc', async () => {
    await assertFails(setDoc(doc(db('u2'), userPath('u1')), newCreate('u1')));
  });

  it('counts later opens up, never down', async () => {
    const store = db('u1');
    await setDoc(doc(store, userPath('u1')), newCreate('u1'));
    await assertSucceeds(updateDoc(doc(store, userPath('u1')), newUpdate()));
    await assertFails(updateDoc(doc(store, userPath('u1')), { lastOpenAt: serverTimestamp(), opens: 1 }));
  });

  it('still takes an old build’s update on a doc that has a count', async () => {
    const store = db('u1');
    await setDoc(doc(store, userPath('u1')), newCreate('u1'));
    await assertSucceeds(updateDoc(doc(store, userPath('u1')), { lastOpenAt: serverTimestamp(), platform: 'ios' }));
  });

  it('starts the count on a doc an old build created', async () => {
    const store = db('u1');
    await setDoc(doc(store, userPath('u1')), oldCreate('u1'));
    await assertSucceeds(updateDoc(doc(store, userPath('u1')), newUpdate()));
  });

  it('lets an admin list the day', async () => {
    await setDoc(doc(db('u1'), userPath('u1')), newCreate('u1'));
    await assertSucceeds(getDocs(collection(db('ops', true), `daily_activity/${DAY}/users`)));
    await assertFails(getDocs(collection(db('u2'), `daily_activity/${DAY}/users`)));
  });
});

describe('daily_activity guests', () => {
  const guestPath = `daily_activity/${DAY}/guests/${INSTALL}`;
  const guest = { installId: INSTALL, platform: 'android', appVersion: '1.1.0', build: 19, opens: 1 };

  it('only admins read them', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore() as unknown as Firestore, guestPath), guest);
    });
    await assertSucceeds(getDocs(collection(db('ops', true), `daily_activity/${DAY}/guests`)));
    await assertFails(getDocs(collection(db('u1'), `daily_activity/${DAY}/guests`)));
    await assertFails(getDocs(collection(db(null), `daily_activity/${DAY}/guests`)));
  });

  it('no client writes them, not even an admin', async () => {
    await assertFails(setDoc(doc(db(null), guestPath), guest));
    await assertFails(setDoc(doc(db('u1'), guestPath), guest));
    await assertFails(setDoc(doc(db('ops', true), guestPath), guest));
  });
});
```

- [ ] **Step 3: Run it to see it fail**

Run (from `firestore/rules_test`, Node on PATH):

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx vitest run activity.test.ts
```

Expected: the new-shape create and the update cases fail (the current rules allow only the four old keys), and the guest-admin read fails (no rule matches).

- [ ] **Step 4: Change the rules**

In `firestore/firestore.rules`, replace `validActivityCreate`, `validActivityUpdate` and the `daily_activity` match with:

```
    // Keys of an app-open doc. opens, appVersion, build and installId came in
    // 1.1.x; docs from older builds have only the first four.
    function activityKeys() {
      return ['uid', 'firstOpenAt', 'lastOpenAt', 'platform',
        'opens', 'appVersion', 'build', 'installId'];
    }

    // The same install ID pattern as workers/activity/src/open.ts and
    // lib/data/repositories/activity_install_id.dart.
    function validActivityExtras(data) {
      return (!('opens' in data) || (data.opens is int && data.opens >= 1 && data.opens <= 100000))
        && (!('appVersion' in data) || (data.appVersion is string
          && data.appVersion.size() >= 1 && data.appVersion.size() <= 32))
        && (!('build' in data) || (data.build is int && data.build >= 0 && data.build <= 10000000))
        && (!('installId' in data) || (data.installId is string
          && data.installId.matches('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    }

    function validActivityCreate() {
      return request.resource.data.keys().hasOnly(activityKeys())
        && request.resource.data.uid == request.auth.uid
        && request.resource.data.firstOpenAt == request.time
        && request.resource.data.lastOpenAt == request.time
        && validActivityPlatform()
        && validActivityExtras(request.resource.data)
        && (!('opens' in request.resource.data) || request.resource.data.opens == 1);
    }

    // An older build's update leaves opens alone; a newer one counts it up.
    function validActivityUpdate() {
      return request.resource.data.keys().hasOnly(activityKeys())
        && request.resource.data.uid == resource.data.uid
        && request.resource.data.firstOpenAt == resource.data.firstOpenAt
        && request.resource.data.lastOpenAt == request.time
        && validActivityPlatform()
        && validActivityExtras(request.resource.data)
        && (!('opens' in resource.data)
          || ('opens' in request.resource.data
            && request.resource.data.opens >= resource.data.opens));
    }

    match /daily_activity/{dayId}/users/{uid} {
      allow read: if isAdmin() || isOwner(uid);
      allow create: if isOwner(uid)
        && validActivityDayId(dayId)
        && validActivityCreate();
      allow update: if isOwner(uid)
        && validActivityDayId(dayId)
        && validActivityUpdate();
      allow delete: if false;
    }

    // Guests' opens: written only by workers/activity (service account).
    match /daily_activity/{dayId}/guests/{installId} {
      allow read: if isAdmin();
      allow write: if false;
    }
```

Leave `validActivityDayId` and `validActivityPlatform` as they are.

- [ ] **Step 5: Run the rules tests (new and existing)**

```bash
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx vitest run
```

Expected: every file passes, `activity.test.ts` included.

- [ ] **Step 6: Write the pins test**

`test/firestore/activity_pins_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/data/repositories/activity_install_id.dart';

/// The app makes install IDs, the activity Worker checks them and the rules
/// check them again on the signed-in doc. Pin one pattern and one platform
/// list across all three.
void main() {
  late String rules;
  late String worker;

  setUpAll(() {
    rules = File('firestore/firestore.rules').readAsStringSync();
    worker = File('workers/activity/src/open.ts').readAsStringSync();
  });

  test('one install ID pattern', () {
    expect(rules, contains("matches('$installIdPattern')"));
    expect(
      worker,
      contains("export const INSTALL_ID_PATTERN = '$installIdPattern';"),
    );
  });

  test('one platform list', () {
    expect(rules, contains("in ['ios', 'android', 'other']"));
    expect(worker, contains("PLATFORMS = ['ios', 'android', 'other']"));
  });
}
```

- [ ] **Step 7: Run it**

Run: `flutter test test/firestore/activity_pins_test.dart`
Expected: 2 passed.

- [ ] **Step 8: Commit**

```bash
dart format test/firestore/activity_pins_test.dart
git add firestore/firestore.rules firestore/rules_test/activity.test.ts test/firestore/activity_pins_test.dart
git commit -m "feat(rules): open counts, app versions and guest opens in daily_activity"
```

---

### Task 7: Docs

**Files:**
- Modify: `FIREBASE.md`: data model block (about line 258), rule note 6 (about line 320), the data paragraph (about line 343)
- Modify: `docs/privacy/index.html` (about line 202)
- Modify: `README.md`: the Workers line (about line 325), the repo tree line (about line 339), and the deploy checklist section next to the leaderboard Worker step (about line 99)

- [ ] **Step 1: FIREBASE.md**

Data model block, replace the `daily_activity` lines with:

```
daily_activity/{yyyy-MM-dd}/users/{uid}
  uid, firstOpenAt, lastOpenAt, platform,
  opens, appVersion, build, installId          # 1.1.x on; older docs lack them
daily_activity/{yyyy-MM-dd}/guests/{installId} # written by workers/activity only
  installId, firstOpenAt, lastOpenAt, platform, opens, appVersion, build
```

Rule note 6: say that the owner may also write `opens` (1 on create, never lower after), `appVersion`, `build` and `installId`; that `guests` are admin-read only and written by the activity Worker's service account; and that the rules must be deployed before the 1.1.x app ships.

Data paragraph: "`daily_activity` stores uid, first/last open time and platform" becomes "`daily_activity` stores, per player per day, uid, first/last open time, platform, open count, app version/build and install ID; guests' opens are stored per install ID with the same fields (no account)".

- [ ] **Step 2: Privacy policy**

In `docs/privacy/index.html`, replace `a daily app-open record (uid, first/last open time, platform);` with:

```html
a daily app-open record (uid, first/last open time, platform, how many
          times you opened the app that day, app version, and an install ID
          the app creates); if you use the app without signing in, the same
          daily record keyed by that install ID instead of an account;
```

- [ ] **Step 3: README**

- Workers line (about 325): add `workers/activity` (guests' app opens; needs the `FIREBASE_SERVICE_ACCOUNT_JSON` secret).
- Repo tree line (about 339): mention `activity`.
- Deploy checklist, after the leaderboard Worker step, add:
  `- [ ] Deploy the activity Worker: cd workers/activity && npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON && npm run deploy (Firestore write). Deploy the rules first: the 1.1.x app writes opens, appVersion, build and installId to daily_activity.`

- [ ] **Step 4: Commit**

```bash
git add FIREBASE.md README.md docs/privacy/index.html
git commit -m "docs: app opens for guests, open counts and app versions"
```

---

### Task 8: Full verification

- [ ] **Step 1:** `flutter analyze`. Expected: the same issue count as the pre-change baseline (infos only), and nothing in touched files.
- [ ] **Step 2:** `flutter test`. Expected: all pass. Report the count.
- [ ] **Step 3:** In `workers/activity`: `npx vitest run && npx tsc -p tsconfig.json`. All pass.
- [ ] **Step 4:** In `firestore/rules_test`, with the emulator up: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npx vitest run`. All pass.
- [ ] **Step 5:** `git status`. Clean; `pubspec.lock` unchanged.
