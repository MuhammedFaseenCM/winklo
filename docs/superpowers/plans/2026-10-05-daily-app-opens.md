# Daily app opens (DAU) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Near-real-time unique signed-in app-open counts in the Ops Console (date picker) plus a Firebase Analytics `app_open` event and console link.

**Architecture:** Flutter records opens to Firestore `daily_activity/{yyyy-MM-dd}/users/{uid}` (throttled) and logs FA `app_open`. Admin counts that collection client-side like other dashboard KPIs.

**Tech Stack:** Flutter/Dart (BLoC DI, Firestore, Firebase Analytics, SharedPreferences), winklo-admin (React/Vite, Firestore SDK, Vitest).

**Spec:** `docs/superpowers/specs/2026-10-05-daily-app-opens-design.md`

## Global Constraints

- Signed-in users only for Firestore DAU; silent/best-effort failures; never block UI.
- Day id = device-local `yyyy-MM-dd` via `leaderboardDayId()` / `AppCalendar.dateIdDashed`.
- Throttle: at most one successful record every 5 minutes.
- Admin day picker uses browser-local `localTodayDashed` / `stepDashedDay`.
- No new Worker endpoint.
- Follow existing domain/data/DI patterns; `dart format` on Dart changes.
- Admin KPI card work lands in repo `winklo-admin`; app/rules work in `winklo`.

---

## File structure

### winklo (app)

| File | Responsibility |
|------|----------------|
| `lib/domain/repositories/activity_repository.dart` | Interface: record open + local last-recorded timestamp |
| `lib/domain/usecases/record_app_open.dart` | Auth gate, throttle, day id, analytics |
| `lib/data/repositories/activity_repository_impl.dart` | Firestore upsert + SharedPreferences throttle stamp |
| `lib/domain/repositories/analytics_repository.dart` | Add `logAppOpen` |
| `lib/data/repositories/firebase_analytics_repository_impl.dart` | Implement `logAppOpen` |
| `lib/core/di/app_repositories.dart` | Register ActivityRepository + RecordAppOpen |
| `lib/core/lifecycle/app_open_lifecycle.dart` | WidgetsBindingObserver that calls RecordAppOpen |
| `lib/app.dart` | Mount lifecycle observer |
| `firestore/firestore.rules` | `daily_activity` rules |
| `FIREBASE.md` | Short deploy note for rules |
| `test/domain/usecases/record_app_open_test.dart` | Usecase tests |
| `test/data/repositories/firebase_analytics_repository_impl_test.dart` | Include `logAppOpen` no-op |

### winklo-admin

| File | Responsibility |
|------|----------------|
| `src/lib/dashboardKpis.ts` | `fetchAppOpenCount(dayId)` |
| `src/lib/dashboardKpis.test.ts` | Path helper / day tests if extracted |
| `src/lib/firebaseAnalyticsConsole.ts` | Console URL constant |
| `src/pages/DashboardPage.tsx` | KPI + date picker + FA link |
| `src/styles.css` | Minimal styles for date control if needed |

---

### Task 1: Domain — ActivityRepository + RecordAppOpen (TDD)

**Files:**
- Create: `lib/domain/repositories/activity_repository.dart`
- Create: `lib/domain/usecases/record_app_open.dart`
- Create: `test/domain/usecases/record_app_open_test.dart`

**Interfaces:**
- Produces:
  - `ActivityRepository.recordOpen({required String uid, required String dayId, required String platform, required DateTime at})`
  - `ActivityRepository.lastRecordedAt()` → `DateTime?`
  - `ActivityRepository.markRecorded(DateTime at)` → `Future<void>`
  - `RecordAppOpen.call({DateTime? now, String? platform})` → `Future<void>`
- Consumes: `AuthRepository.currentUser`, `AnalyticsRepository` (will add `logAppOpen` in Task 2 — stub/mock for now)

- [ ] **Step 1: Write failing usecase tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:winklo/domain/entities/app_user.dart';
import 'package:winklo/domain/repositories/activity_repository.dart';
import 'package:winklo/domain/repositories/analytics_repository.dart';
import 'package:winklo/domain/repositories/auth_repository.dart';
import 'package:winklo/domain/usecases/record_app_open.dart';

class _MockAuth extends Mock implements AuthRepository {}
class _MockActivity extends Mock implements ActivityRepository {}
class _MockAnalytics extends Mock implements AnalyticsRepository {}

void main() {
  late _MockAuth auth;
  late _MockActivity activity;
  late _MockAnalytics analytics;
  late RecordAppOpen usecase;

  setUp(() {
    auth = _MockAuth();
    activity = _MockActivity();
    analytics = _MockAnalytics();
    usecase = RecordAppOpen(auth, activity, analytics);
    when(() => activity.markRecorded(any())).thenAnswer((_) async {});
    when(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    ).thenAnswer((_) async {});
    when(() => analytics.logAppOpen(platform: any(named: 'platform')))
        .thenAnswer((_) async {});
  });

  test('no-ops when signed out', () async {
    when(() => auth.currentUser).thenReturn(null);
    await usecase(now: DateTime(2026, 10, 5, 12));
    verifyNever(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    );
  });

  test('records open and analytics when signed in', () async {
    when(() => auth.currentUser).thenReturn(
      const AppUser(uid: 'u1', displayName: 'A', email: 'a@b.c'),
    );
    when(() => activity.lastRecordedAt()).thenReturn(null);

    final now = DateTime(2026, 10, 5, 12, 0);
    await usecase(now: now, platform: 'android');

    verify(
      () => activity.recordOpen(
        uid: 'u1',
        dayId: '2026-10-05',
        platform: 'android',
        at: now,
      ),
    ).called(1);
    verify(() => activity.markRecorded(now)).called(1);
    verify(() => analytics.logAppOpen(platform: 'android')).called(1);
  });

  test('skips when within 5 minute throttle', () async {
    when(() => auth.currentUser).thenReturn(
      const AppUser(uid: 'u1', displayName: 'A', email: 'a@b.c'),
    );
    final now = DateTime(2026, 10, 5, 12, 0);
    when(() => activity.lastRecordedAt())
        .thenReturn(now.subtract(const Duration(minutes: 2)));

    await usecase(now: now, platform: 'android');

    verifyNever(
      () => activity.recordOpen(
        uid: any(named: 'uid'),
        dayId: any(named: 'dayId'),
        platform: any(named: 'platform'),
        at: any(named: 'at'),
      ),
    );
  });
}
```

Adjust `AppUser` constructor fields to match the real entity if they differ.

- [ ] **Step 2: Run tests — expect FAIL (missing types)**

Run: `dart test test/domain/usecases/record_app_open_test.dart`  
Expected: FAIL — `ActivityRepository` / `RecordAppOpen` / `logAppOpen` missing

- [ ] **Step 3: Implement domain interfaces + usecase**

`lib/domain/repositories/activity_repository.dart`:

```dart
abstract class ActivityRepository {
  DateTime? lastRecordedAt();

  Future<void> markRecorded(DateTime at);

  Future<void> recordOpen({
    required String uid,
    required String dayId,
    required String platform,
    required DateTime at,
  });
}
```

`lib/domain/usecases/record_app_open.dart`:

```dart
import '../entities/leaderboard_period.dart';
import '../repositories/activity_repository.dart';
import '../repositories/analytics_repository.dart';
import '../repositories/auth_repository.dart';

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
    final user = _auth.currentUser;
    if (user == null) return;

    final at = now ?? DateTime.now();
    final last = _activity.lastRecordedAt();
    if (last != null && at.difference(last) < throttle) return;

    final resolvedPlatform = platform ?? 'other';
    try {
      await _activity.recordOpen(
        uid: user.uid,
        dayId: leaderboardDayId(at),
        platform: resolvedPlatform,
        at: at,
      );
      await _activity.markRecorded(at);
      await _analytics.logAppOpen(platform: resolvedPlatform);
    } catch (_) {
      // Best-effort: never block the app.
    }
  }
}
```

Add to `AnalyticsRepository` (minimal stub so tests compile — full impl in Task 2):

```dart
Future<void> logAppOpen({String? platform});
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `dart test test/domain/usecases/record_app_open_test.dart`  
Expected: PASS

- [ ] **Step 5: Commit (winklo)**

```bash
git add lib/domain/repositories/activity_repository.dart \
  lib/domain/usecases/record_app_open.dart \
  lib/domain/repositories/analytics_repository.dart \
  test/domain/usecases/record_app_open_test.dart
git commit -m "$(cat <<'EOF'
feat: add RecordAppOpen usecase for daily DAU tracking

EOF
)"
```

---

### Task 2: Firebase Analytics `app_open`

**Files:**
- Modify: `lib/data/repositories/firebase_analytics_repository_impl.dart`
- Modify: `test/data/repositories/firebase_analytics_repository_impl_test.dart`

**Interfaces:**
- Consumes: `AnalyticsRepository.logAppOpen`
- Produces: FA event `app_open` with optional `platform` param

- [ ] **Step 1: Extend no-op test**

Add `await repo.logAppOpen(platform: 'android');` to the existing Firebase-not-ready test.

- [ ] **Step 2: Run test — expect FAIL if method unimplemented**

Run: `dart test test/data/repositories/firebase_analytics_repository_impl_test.dart`

- [ ] **Step 3: Implement**

```dart
@override
Future<void> logAppOpen({String? platform}) {
  return _safe((a) {
    final parameters = <String, Object>{};
    if (platform != null && platform.isNotEmpty) {
      parameters['platform'] = platform;
    }
    return a.logEvent(
      name: 'app_open',
      parameters: parameters.isEmpty ? null : parameters,
    );
  });
}
```

- [ ] **Step 4: Run test — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/firebase_analytics_repository_impl.dart \
  test/data/repositories/firebase_analytics_repository_impl_test.dart
git commit -m "$(cat <<'EOF'
feat: log throttled app_open Firebase Analytics event

EOF
)"
```

---

### Task 3: ActivityRepositoryImpl (Firestore + prefs)

**Files:**
- Create: `lib/data/repositories/activity_repository_impl.dart`
- Create: `test/data/repositories/activity_repository_impl_test.dart` (prefs + no-op when Firebase not ready; mock Firestore only if project already mocks it — otherwise test prefs + skip remote when `FirebaseBootstrap.isReady == false`)

**Interfaces:**
- Consumes: `SharedPreferences`, `FirebaseFirestore?`, `FirebaseBootstrap.isReady`
- Produces: concrete `ActivityRepository`

- [ ] **Step 1: Prefs throttle tests**

```dart
test('markRecorded / lastRecordedAt round-trip via SharedPreferences', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = ActivityRepositoryImpl(prefs);
  expect(repo.lastRecordedAt(), isNull);
  final at = DateTime.utc(2026, 10, 5, 12);
  await repo.markRecorded(at);
  expect(repo.lastRecordedAt(), at);
});

test('recordOpen no-ops when Firebase is not ready', () async {
  FirebaseBootstrap.isReady = false;
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = ActivityRepositoryImpl(prefs);
  await repo.recordOpen(
    uid: 'u1',
    dayId: '2026-10-05',
    platform: 'android',
    at: DateTime(2026, 10, 5),
  );
});
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Implement**

```dart
class ActivityRepositoryImpl implements ActivityRepository {
  ActivityRepositoryImpl(this._prefs, {FirebaseFirestore? firestore})
    : _firestore = firestore;

  static const _lastKey = 'activity_last_recorded_at_ms';

  final SharedPreferences _prefs;
  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.isReady) return null;
    return _firestore ?? FirebaseFirestore.instance;
  }

  @override
  DateTime? lastRecordedAt() {
    final ms = _prefs.getInt(_lastKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  Future<void> markRecorded(DateTime at) async {
    await _prefs.setInt(_lastKey, at.toUtc().millisecondsSinceEpoch);
  }

  @override
  Future<void> recordOpen({
    required String uid,
    required String dayId,
    required String platform,
    required DateTime at,
  }) async {
    final db = _db;
    if (db == null) return;
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
        });
      } else {
        await ref.update({
          'lastOpenAt': FieldValue.serverTimestamp(),
          'platform': platform,
        });
      }
    } catch (e, st) {
      debugPrint('Activity recordOpen failed: $e');
      debugPrint('$st');
      rethrow; // usecase catches
    }
  }
}
```

Compare `lastRecordedAt` using the same clock basis as `now` in the usecase (prefer storing UTC ms; compare with `at.toUtc()` in throttle check if needed — keep usecase and prefs consistent).

- [ ] **Step 4: Run tests — PASS; `dart format` touched files**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: persist daily app opens to Firestore activity collection

EOF
)"
```

---

### Task 4: Firestore rules for `daily_activity`

**Files:**
- Modify: `firestore/firestore.rules`
- Modify: `FIREBASE.md` (short note: deploy rules)

- [ ] **Step 1: Add match block** (before closing of database match)

```
function validActivityDayId(dayId) {
  return dayId.matches('^[0-9]{4}-[0-9]{2}-[0-9]{2}$');
}

function validActivityPlatform() {
  return request.resource.data.platform is string
    && request.resource.data.platform in ['ios', 'android', 'other'];
}

function validActivityCreate() {
  return request.resource.data.keys().hasOnly([
      'uid', 'firstOpenAt', 'lastOpenAt', 'platform'
    ])
    && request.resource.data.uid == request.auth.uid
    && request.resource.data.firstOpenAt == request.time
    && request.resource.data.lastOpenAt == request.time
    && validActivityPlatform();
}

function validActivityUpdate() {
  return request.resource.data.keys().hasOnly([
      'uid', 'firstOpenAt', 'lastOpenAt', 'platform'
    ])
    && request.resource.data.uid == resource.data.uid
    && request.resource.data.firstOpenAt == resource.data.firstOpenAt
    && request.resource.data.lastOpenAt == request.time
    && validActivityPlatform();
}

match /daily_activity/{dayId}/users/{uid} {
  allow read: if isAdmin();
  allow create: if isOwner(uid)
    && validActivityDayId(dayId)
    && validActivityCreate();
  allow update: if isOwner(uid)
    && validActivityDayId(dayId)
    && validActivityUpdate();
  allow delete: if false;
}
```

Note: client uses `FieldValue.serverTimestamp()` which rules see as `request.time` — matches existing `client_errors` pattern.

- [ ] **Step 2: Document deploy in FIREBASE.md** (one checklist bullet: deploy `firestore/firestore.rules`)

- [ ] **Step 3: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: allow owner writes and admin reads for daily_activity

EOF
)"
```

---

### Task 5: DI + app lifecycle hook

**Files:**
- Modify: `lib/core/di/app_repositories.dart`
- Create: `lib/core/lifecycle/app_open_lifecycle.dart`
- Modify: `lib/app.dart`

**Interfaces:**
- Consumes: `RecordAppOpen`, `AuthRepository` (via usecase)
- Produces: opens recorded on start + resume

- [ ] **Step 1: Register providers**

```dart
RepositoryProvider<ActivityRepository>(
  create: (context) => ActivityRepositoryImpl(context.read<SharedPreferences>()),
),
RepositoryProvider<RecordAppOpen>(
  create: (context) => RecordAppOpen(
    context.read<AuthRepository>(),
    context.read<ActivityRepository>(),
    context.read<AnalyticsRepository>(),
  ),
),
```

Place near `AuthRepository` / `AnalyticsRepository`.

- [ ] **Step 2: Lifecycle helper**

```dart
class AppOpenLifecycle with WidgetsBindingObserver {
  AppOpenLifecycle(this._recordAppOpen);

  final RecordAppOpen _recordAppOpen;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_ping());
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_ping());
    }
  }

  Future<void> _ping() {
    return _recordAppOpen(platform: defaultTargetPlatform.name.toLowerCase());
  }
}
```

Map platform: if name is `iOS` → `ios`, `android` → `android`, else `other` (normalize to rules allow-list).

- [ ] **Step 3: Wire in `WinkloApp`**

In `_WinkloAppState`: create `AppOpenLifecycle` in `didChangeDependencies` once (after repositories available), `dispose` it in `dispose()`.

Also listen to auth: when user signs in, call `_ping()` once (AuthCubit listener or call from lifecycle after auth ready). Simplest: call `_ping()` on start and on resume; usecase no-ops if signed out — when they sign in later, next resume or an explicit call after sign-in is needed.

**Sign-in gap fix:** In `AppOpenLifecycle.start`, also subscribe to `context.read<AuthRepository>().authStateChanges()` and ping when uid becomes non-null (cancel on dispose).

- [ ] **Step 4: Analyze changed files**

Run: `dart analyze lib/domain/usecases/record_app_open.dart lib/data/repositories/activity_repository_impl.dart lib/core/lifecycle/app_open_lifecycle.dart lib/app.dart lib/core/di/app_repositories.dart`  
Expected: no issues

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: record app opens on start, resume, and sign-in

EOF
)"
```

---

### Task 6: Admin — fetch app-open count helper

**Repo:** `winklo-admin`

**Files:**
- Modify: `src/lib/dashboardKpis.ts`
- Modify: `src/lib/dashboardKpis.test.ts`
- Create: `src/lib/firebaseAnalyticsConsole.ts`

- [ ] **Step 1: Add helper + URL**

```ts
// firebaseAnalyticsConsole.ts
export const FIREBASE_ANALYTICS_CONSOLE_URL =
  'https://console.firebase.google.com/project/brain-zip-app/analytics';

// dashboardKpis.ts
export function dailyActivityUsersPath(dayId: string): string {
  return `daily_activity/${dayId}/users`;
}

export async function fetchAppOpenCount(dayId: string): Promise<number> {
  const col = collection(db, dailyActivityUsersPath(dayId));
  try {
    const snap = await getCountFromServer(col);
    return snap.data().count;
  } catch {
    const snap = await getDocs(query(col, limit(500)));
    return snap.size;
  }
}
```

- [ ] **Step 2: Test path helper**

```ts
it('builds daily activity users path', () => {
  expect(dailyActivityUsersPath('2026-10-05')).toBe(
    'daily_activity/2026-10-05/users',
  );
});
```

- [ ] **Step 3: Run** `npm test -- src/lib/dashboardKpis.test.ts` (or project’s vitest script) — PASS

- [ ] **Step 4: Commit in winklo-admin**

```bash
git commit -m "$(cat <<'EOF'
feat: add dashboard helper for daily app-open counts

EOF
)"
```

---

### Task 7: Admin — Dashboard KPI + date picker + FA link

**Repo:** `winklo-admin`

**Files:**
- Modify: `src/pages/DashboardPage.tsx`
- Modify: `src/styles.css` only if needed for a compact date row inside the card

- [ ] **Step 1: State**

```ts
const [openDay, setOpenDay] = useState(getLocalToday);
const [appOpens, setAppOpens] = useState<KpiState<number>>({ status: 'loading' });

// in refresh / separate effect when openDay changes:
void fetchAppOpenCount(openDay)
  .then((data) => setAppOpens({ status: 'ready', data }))
  .catch((err) => setAppOpens({ status: 'error', message: kpiFailureMessage(err) }));
```

- [ ] **Step 2: UI card** (first or second in `hero-stats-grid`)

- Label: `App opens`
- Value: count or `…` / `—`
- Sub: `{openDay} · unique signed-in openers`
- Controls (stop Link navigation from stealing clicks — use a `div.stat-box` variant **without** wrapping the whole card in `Link`, or put controls outside):
  - `<input type="date" value={openDay} onChange=... />`
  - prev/next buttons via `stepDashedDay(openDay, ±1)`
- External: `<a href={FIREBASE_ANALYTICS_CONSOLE_URL} target="_blank" rel="noreferrer">Firebase Analytics</a>`

Do **not** route `to="/platform"` for this card; it is self-contained on the dashboard.

- [ ] **Step 3: Manual check locally**

1. Deploy/rules emulator or staging rules with Task 4.
2. Sign in on app → confirm doc `daily_activity/{today}/users/{uid}`.
3. Admin dashboard shows `1` for today; other day shows `0`.
4. FA DebugView (optional) shows `app_open`.

- [ ] **Step 4: Commit in winklo-admin**

```bash
git commit -m "$(cat <<'EOF'
feat: show daily app opens KPI with date picker on dashboard

EOF
)"
```

---

### Task 8: Spec coverage check + release note

- [ ] **Step 1: Verify against spec**

| Spec item | Task |
|-----------|------|
| Firestore daily_activity model | 3, 4 |
| Throttle 5 min | 1, 3 |
| FA `app_open` | 2 |
| Lifecycle start/resume + signed-in | 5 |
| Admin count + date picker | 6, 7 |
| FA console link | 6, 7 |
| No Worker endpoint | 6, 7 |
| Pre-release days = 0 | emergent |

- [ ] **Step 2: Note for release**

App store release required before admin numbers populate. Deploy Firestore rules **before** or with the app release.

- [ ] **Step 3: Final commits only if docs tweaks remain**

---

## Manual test plan (end-to-end)

1. Deploy `firestore/firestore.rules`.
2. Install build with Tasks 1–5.
3. Sign in → open app → Firestore has today’s user doc.
4. Background < 5 min → resume → still one doc; `lastOpenAt` may update only after throttle window.
5. Admin: today count ≥ 1; pick yesterday → 0 (unless tested yesterday).
6. Click Firebase Analytics link → console opens.
7. Signed-out session → no new Firestore writes.
