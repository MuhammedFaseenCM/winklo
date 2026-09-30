# Debug daily play period (dart-define)

Date: 2026-09-30  
Status: approved  
Repo: winklo  

## Goal

Allow debug builds to use **release-like calendar-day** puzzle IDs (`daily_YYYYMMDD`) so admin CMS overrides load, without removing the existing per-minute debug rotation.

## Decision

- `--dart-define=DAILY_PLAY_PERIOD=true` disables minute play period in debug.
- Default debug behavior unchanged (minute rotation) when the define is absent/false.
- Widget tests keep using `DevFlags.useDailyPlayPeriodInTests = true`.
- Add VS Code / Cursor launch configs for both modes.
