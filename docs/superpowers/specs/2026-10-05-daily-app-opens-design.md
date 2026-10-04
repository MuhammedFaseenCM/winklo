# Daily app opens (DAU) in admin — design

Date: 2026-10-05  
Status: approved for implementation  
Repos: winklo + winklo-admin  

## Goal

Show **unique signed-in users who opened the app** for a selected calendar day in the Ops Console (near real-time), and keep a link to **Firebase Analytics** for deeper historical reporting.

## Product decisions

| Topic | Choice |
|-------|--------|
| Metric | Unique users who launched or resumed the app that day (DAU) |
| Admin surface | Dashboard KPI + date picker (any past day) + Firebase Analytics link |
| Freshness | Near real-time via Firestore client writes |
| Firebase Analytics | Already enabled; add throttled custom `app_open` event |
| Who counts in admin | Signed-in users only (guest/anonymous opens remain FA-only) |
| Day boundary | Device-local `yyyy-MM-dd` (same helper style as daily leaderboards) |
| Approach | Hybrid (Approach 3): Firestore for admin KPI + FA for console deep dive |

## Approach

**Approach 3 — Hybrid** (chosen over Firestore-only and GA4 Data API-only):

- Firestore `daily_activity` powers near-real-time admin counts and date picking without a Worker endpoint.
- Firebase Analytics keeps the existing product analytics surface; `app_open` aligns console reporting with app opens.
- GA4 Data API alone was rejected for v1 because it does not meet the near-real-time requirement and needs extra GCP auth.

## Architecture

```
Flutter (signed-in)
  cold start / AppLifecycleState.resumed
        │  (≤ once / 5 minutes)
        ├─→ RecordAppOpen
        │     └─→ ActivityRepository → Firestore
        │           daily_activity/{yyyy-MM-dd}/users/{uid}
        └─→ AnalyticsRepository.logAppOpen → Firebase Analytics

Admin dashboard (winklo-admin)
  date picker (default: browser-local today)
        └─→ getCountFromServer(daily_activity/{day}/users)
  + external link → Firebase Analytics console
```

No new admin Worker dashboard endpoint (same client-side KPI pattern as “Today’s scores”).

## Data model

```
daily_activity/{yyyy-MM-dd}/users/{uid}:
  uid: string
  firstOpenAt: timestamp   // set on create only
  lastOpenAt: timestamp    // updated on later opens that day
  platform: string         // ios | android | other
```

- One document per user per day ⇒ document count = unique openers for that day.
- Day id: device-local `yyyy-MM-dd` via the same calendar helper used for daily leaderboards (`leaderboardDayId()` / equivalent).

## Flutter app

### New / extended pieces

| Layer | Piece |
|-------|--------|
| Domain | `ActivityRepository` interface |
| Domain | `RecordAppOpen` usecase (auth check + throttle orchestration) |
| Data | Firestore `ActivityRepositoryImpl` |
| Domain/Data | `AnalyticsRepository.logAppOpen()` + Firebase impl |
| App | App-level lifecycle observer (root/`WinkloApp` or bootstrap listener — not per game screen) |
| DI | Register repository + usecase in `core/di` |

### When to record

1. Firebase Auth has a non-null `uid`.
2. Cold start after auth is ready.
3. `AppLifecycleState.resumed`.

### Throttle

- At most one successful record every **5 minutes** (in-memory + light local cache so process restarts do not spam).
- Within a day, later successful records **update** `lastOpenAt` (and may refresh `platform`); they do not create a second unique user.
- Failures are silent / best-effort; never block UI.

### Firebase Analytics

- Event name: `app_open`
- Optional parameter: `platform`
- Same throttle as Firestore writes.

## Firestore rules

```
match /daily_activity/{dayId}/users/{uid} {
  // create/update: isOwner(uid), dayId matches yyyy-MM-dd,
  //   allowed keys only (uid, firstOpenAt, lastOpenAt, platform)
  // read: isAdmin()  // Ops Console counts
  // delete: false
}
```

Exact validation mirrors other owner-write collections (typed fields, no arbitrary keys).

## Admin panel (winklo-admin)

### Dashboard KPI

| Element | Behavior |
|---------|----------|
| Card label | App opens |
| Default day | Browser-local today (`localTodayDashed`) |
| Date control | Date input and/or prev/next day |
| Value | `getCountFromServer` on `daily_activity/{day}/users` (fallback bounded `getDocs` like other KPIs) |
| Subtext | Selected date + “unique signed-in openers” |
| External link | “Open in Firebase Analytics” → project console URL (config constant) |
| Loading / errors / refresh | Same patterns as existing dashboard KPIs |

### Timezone note

Admin “today” uses the operator’s browser timezone; each user’s day key uses their device timezone. Same class of caveat as daily leaderboards — accepted for v1.

## Historical / pre-release data

- Calendar days before the app version that includes this tracking ship show **0** in admin (no backfill).
- Firebase Analytics still has historical sessions; operators use the console link for that history.

## Testing

### App

- Unit: `RecordAppOpen` skips when signed out; respects throttle; uses correct day id.
- Repository tests/mocks: create sets `firstOpenAt` + `lastOpenAt`; update refreshes `lastOpenAt` only.

### Admin

- `dashboardKpis` helper tests for path/day and count helpers.
- Manual: open signed-in app → refresh admin → count +1 once; reopen within 5 minutes does not increase unique count.

## Out of scope (v1)

- GA4 Data API inside admin
- Anonymous/guest DAU in Firestore
- Per-platform breakdown in admin UI
- Charts, retention, funnels
- Server-side daily summary aggregation docs
- Backfilling past days from Analytics

## Repos touched

| Repo | Changes |
|------|---------|
| `winklo` | Activity tracking, `app_open` analytics, Firestore rules, DI, lifecycle hook |
| `winklo-admin` | Dashboard KPI, date picker, FA console link, KPI helper tests |
