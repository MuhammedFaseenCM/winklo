# App notifications — design

Date: 2026-09-24  
Status: approved for implementation  
References: Urbania / Unnati / Utkarsh `NotificationClient` + `FirebaseNotificationClient`, adapted to Winklo BLoC clean architecture.

## Goal

Notify players with **local** engagement reminders and **FCM** product messages, without leaderboard pushes.

## Product decisions

| Topic | Choice |
|-------|--------|
| Delivery | Local + FCM (Approach 1) |
| Daily ready | Local, **08:00 device local**, every day |
| Streak at risk | Local, **20:00 device local**, if today’s Zip **or** Path Words not cleared; cancel when both cleared |
| Announcements | FCM topic `announcements` (admin panel later; console for now) |
| App update | FCM topic `app_updates` |
| Leaderboard | Out of scope |
| Calendar | Device **local** (same as `StreakCalculator`) |
| Permission | Soft request once; fail soft if denied |
| Settings UI | None in v1 (system permission only) |

## Types / payloads

| `data.type` | Delivery | Tap default |
|-------------|----------|-------------|
| `daily_ready` | Local | `/` |
| `streak_at_risk` | Local | `/` |
| `announcement` | FCM | `/` (optional `data.route`) |
| `app_update` | FCM | `/` |

## Architecture

```
NotificationClient (data/clients/notification)
  └─ FirebaseNotificationClient (FCM + flutter_local_notifications)

NotificationRepository (domain)
  └─ NotificationRepositoryImpl

Usecases: InitializeNotifications, SyncFcmToken,
          ScheduleEngagementNotifications, HandleNotificationTap

DI: MultiRepositoryProvider (no GetX)
Init: after FirebaseBootstrap in main
Auth: sync fcmToken to users/{uid} + subscribe topics; clear on sign-out
Home load/resume + after daily clear: refresh schedules
```

## Token / topics

- On sign-in: request permission if needed, get FCM token, merge onto `users/{uid}`, subscribe `announcements` + `app_updates`
- On sign-out: unsubscribe best-effort, clear token field / regenerate token

## Errors

Fail soft when Firebase not ready, permission denied, or schedule/token fails. Local scores and play remain available.

## Out of scope

Admin panel, leaderboard notifications, per-type in-app toggles, Cloud Functions schedulers, iOS primary (Darwin stubs OK).
