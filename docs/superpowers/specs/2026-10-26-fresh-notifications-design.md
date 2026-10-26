# Fresh notifications (app) — design

Date: 2026-10-26
Status: approved, building
Branches: `fix/scheduled-reminders` (1.1.7+26), then `feat/fresh-reminders` on top of it
Admin half: winklo-admin `docs/2026-10-26-admin-variant-pools-design.md`

## Problem

1. **No reminder the app schedules has ever been shown on Android.** The 08:00 daily, the streak-at-risk warning and the Sunday recap all use `zonedSchedule`, whose alarm broadcasts to flutter_local_notifications' `ScheduledNotificationReceiver`. Since v16 the plugin no longer declares that receiver; the app has to, and never did. Neither merged manifest in `build/` mentions it. `zonedSchedule` still succeeds, so nothing ever failed. FCM pushes post at once (`show()`, no alarm) and were never affected.
2. **The daily reminder could never change its words.** `DailyReadyReminder` was a daily repeat (`matchDateTimeComponents: time`); Android stores a scheduled notification's text when it is scheduled, so every morning would read "Today's puzzles are ready / Play Zip, Path Words and Sudoku to keep your streaks going." The streak and recap reminders had one wording each.

## Goal

Every reminder a player sees reads differently from the last one, sounds like Winklo, and stops nagging when the player has stopped opening the app.

## Decisions

| Topic | Choice |
|-------|--------|
| Fix | Declare `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` (BOOT_COMPLETED, MY_PACKAGE_REPLACED, QUICKBOOT_POWERON ×2). A manifest test guards both. Ships alone as 1.1.7+26 on `fix/scheduled-reminders` |
| Daily reminder | One one-off alarm per morning instead of a daily repeat, so each can carry its own words |
| Lapsed players | Taper, then stop: mornings at offsets 0–6 (7 days), then day 10 and day 14, then nothing until the app is opened again. The day-14 line says reminders are pausing |
| Variety | Pools of lines per kind, picked by a date-keyed **shuffle bag**: no line repeats within one pass of its pool, the order changes every pass, and a pass never starts with the line the last one ended on |
| Voice | Mixed: playful, warm and the odd competitive line. Simple English for learners (no idioms, no India-only words), an emoji in about one line in four, never guilt |
| Malayalam | Full pools in `AppTextMl`, flagged for a native speaker's review like the rest of the Malayalam copy |

## Morning reminders (replaces the daily repeat)

### Slots

`EngagementPlanner` plans up to nine `DailyReadyReminder`s at the player's daily time (`dailyReadyMinutes`, default 08:00):

| Slot | Offset from the first morning | Phase | Pool |
|------|------------------------------|-------|------|
| 0 | 0 | `active` | morning lines, or morning streak lines (below) |
| 1–6 | 1–6 days | `lapsed` | "missed a day" lines |
| 7 | 9 days (day 10) | `missYou` | "we miss you" lines |
| 8 | 13 days (day 14) | `lastCall` | lines that say reminders pause |

The first morning is `nextDailyAt(dailyReadyMinutes)`, except that a first morning **today** moves to tomorrow when every game is already cleared today (no "come play" after you've played).

Every refresh (app open, clear, midnight, settings, language) cancels and replans all of them, so a player who opens the app every day only ever receives slot 0. Slot k fires only after k mornings without an open; a clear always needs an open, so slots 1+ mean the player has missed at least a day.

Ids: `scheduleIdMorningBase = 1101` + slot (1101–1109). `engagementScheduleIds` lists them and keeps the legacy `1001`, so the first replan on the new build cancels the old repeat.

### Streak lines on slot 0

Slot 0 uses the streak lines on even rotation days when a streak of **3 or more** days is alive on that morning; otherwise the general morning lines. "Alive on that morning": for a morning today, the longest current streak among uncleared games (decayed, as `GetStreak` returns it); for a morning tomorrow, the longest `StreakCalculator.atStakeTomorrow`. Ties go to Zip, Path Words, Sudoku. The reminder carries `streakGameId` and `streakDays` (0 when none).

## Streak-at-risk and weekly recap

- Streak at risk (tonight and tomorrow evening, unchanged planning) picks its title and body from tiered pools: 1–2 days, 3–6, 7–29, 30+. Lines name the game and days; with `others > 0` the body adds "N more streaks end tonight too" (or the tier's own wording).
- The weekly recap keeps its data-driven body (`weeklyRecapLine`); its **title** rotates by week.

## Picking a line: the shuffle bag

`lib/domain/habit/shuffle_bag.dart`, pure Dart, the same algorithm as winklo-admin's Worker so both can be checked against one set of vectors:

```
pick(key, turn, size):
  size <= 1  -> 0
  size == 2  -> (turn + (fnv1a(key) & 1)) % 2
  run = turn ~/ size, pos = turn % size
  p = order(key, run, size)
  if run > 0 and p[0] == order(key, run - 1, size)[size - 1]: swap p[0], p[1]
  return p[pos]

order(key, run, size) = Fisher–Yates of [0, size) driven by mulberry32(fnv1a("$key#$run"))
```

`fnv1a` and `mulberry32` match `workers/admin-api/src/seeded_random.ts` bit for bit (32-bit arithmetic masked in Dart). Test vectors (turns 20380 onward):

| key | size | sequence |
|-----|------|----------|
| `morning` | 7 | 0 1 5 2 6 2 0 3 5 4 1 6 5 4 2 1 |
| `streak` | 5 | 2 1 3 0 4 2 4 3 0 1 0 2 |
| `uid42\|zip` | 12 | 8 6 2 9 7 11 4 5 0 5 2 11 6 8 7 3 4 10 1 9 8 9 3 6 10 1 |
| `x` | 2 | 1 0 1 0 1 0 |

Turns and keys:

| Pool | key | turn |
|------|-----|------|
| Morning (active) | `active` | the morning's local epoch day |
| Morning streak | `morningStreak` | epoch day ~/ 2 (used on even days) |
| Lapsed | `lapsed` | epoch day |
| Miss you | `missYou` | epoch day |
| Last call | `lastCall` | epoch day |
| Streak at risk | `streakRisk` (each tier is its own pool size, so its own passes) | epoch day of the evening |
| Recap title | `recap` | epoch day ~/ 7 |

The local epoch day is `DateTime.utc(y, m, d).millisecondsSinceEpoch ~/ 86400000` of the reminder's local date. Everyone gets the same line on a given day; that's fine for local reminders.

## Copy layer

- `AppText` gains pools as lists of `NotifCopy` (`typedef NotifCopy = ({String title, String body})`, in `app_text.dart`): `notifMorningLines`, `notifMorningStreakLines(gameId, days)`, `notifLapsedLines`, `notifMissYouLines`, `notifLastCallLines`, `notifStreakRiskLines(gameId, days, {others})` (the tier picks the list), `notifWeeklyRecapTitles`. `AppStrings` forwards them. The old single strings (`notifDailyReady*`, `notifStreakAtRiskTitle`, `notifStreakEndsTonight`, `notifWeeklyRecapTitle`) go once nothing reads them.
- `NotificationRepositoryImpl.engagementCopy` maps each reminder to its pool and `ShuffleBag.pick`.
- Reminder notifications get `BigTextStyleInformation(body)` so a long line (Malayalam especially) expands instead of cutting off.
- Pool sizes (English): morning ≥ 28 (30 written), morning streak ≥ 10, lapsed ≥ 8, miss you ≥ 5, last call ≥ 4, each streak tier ≥ 5, recap titles ≥ 6. Malayalam is a little smaller (20 morning lines, 4 per streak tier) but never empty. English titles ≤ 40 characters, bodies ≤ 90.
- Rules for lines: name real things only (Zip, Path Words, Sudoku, streaks, times); no board sizes or counts that can change; no "you lost your streak" (a freeze may have saved it); the last-call lines say reminders are pausing and that today's puzzles will be waiting.

## Testing

- `android_notification_display_test.dart`: the manifest declares both receivers and the boot actions (fix branch).
- `shuffle_bag_test.dart`: the vectors above; every run of `size` turns covers every index once; no two consecutive turns give the same index (sizes 2–30, many keys).
- `engagement_planner_test.dart`: nine slots at the right days and ids; phases; the all-cleared skip; streak fields for today and tomorrow mornings; off plans none; ids unique across the whole plan.
- `notification_repository_impl_test.dart`: one-offs only (no repeats); each phase draws from its pool; consecutive mornings differ; recap title rotates; the legacy id is cancelled.
- `app_text_test.dart`: pools are non-empty in both languages, sizes meet the minimums in English, Malayalam lines are in Malayalam, English lengths stay under the limits, `{`/`}` never leak.

## Out of scope

Live counts in local reminders (the phone can't know them when the alarm fires), per-player salts, analytics per line, iOS.
