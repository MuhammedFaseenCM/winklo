# Game sound effects (Zip, Path Words, Sudoku)

**Date:** 2026-10-07  
**Status:** Approved for planning  
**Scope:** Gameplay SFX only (no music) for the three daily games, with a persisted in-app mute toggle.

## Goal

Give Zip, Path Words, and Sudoku short feedback sounds for meaningful play moments (tap/step, success, reject, clear), plus a Profile toggle that remembers the player’s preference across launches.

## Non-goals

- Background / ambient music
- Word Match or Category Race SFX (out of v1 scope)
- SFX on hint, notes, erase, or navigation chrome (silent in v1)
- Synthesizing custom audio in-app; we ship curated free-licensed clips
- Overriding system volume or forcing audio in silent mode beyond normal OS behavior

## Architecture

### Shared catalog

`SfxId` enum (shared, not per-feature):

| Id | Role |
|---|---|
| `tap` | Soft confirm: path step / cell select |
| `success` | Positive micro-win: word found / clean digit place |
| `reject` | Illegal or failed attempt |
| `clear` | Puzzle finished / celebrate entry |

Optional `ui` id is **out of v1** unless a toggle click needs a click; default is silent for settings.

### `SfxService` (`lib/core/`)

- Constructed at bootstrap with the current mute flag; **preloads all four clips before the first game screen** (failures are recorded per id, not fatal).
- `play(SfxId)` is fire-and-forget; allows overlapping short clips for rapid path steps.
- No-ops when muted, when that id failed to load, or when the platform player errors.
- Does **not** live in `domain/` (Flutter/audio SDK dependency).
- Registered in existing DI (`MultiRepositoryProvider` / equivalent) so screens and blocs can `context.read<SfxService>()`.

### `SfxSettingsRepository`

- Interface in `domain/repositories/`; impl in `data/` on `SharedPreferences`.
- API: `bool get isEnabled`, `Future<void> setEnabled(bool value)`.
- Prefs key: `sfx_enabled`. **Default: true** when unset.
- `SfxService` keeps an in-memory enabled flag (seeded from prefs at bootstrap; updated when the Profile toggle calls `setEnabled`) so every `play` is a cheap gate.

### Playback package

Use **`audioplayers`** for short overlapping one-shots (pooled players or `play` per clip). No music session / background audio mode.

### Assets

- Curated CC0 / free-licensed pack (e.g. Kenney), trimmed and renamed under `assets/sfx/` as `tap.ogg`, `success.ogg`, `reject.ogg`, `clear.ogg` (`.wav` only if a chosen clip lacks ogg).
- `assets/sfx/ATTRIBUTION.md` (or LICENSE) naming the pack and license.
- Declared in `pubspec.yaml` assets.

## Event → SFX mapping

Play on **meaningful state changes**, not every drag pixel.

### Zip

| Moment | SFX | Notes |
|---|---|---|
| Path extends by one valid cell | `tap` | From successful `extendTo` / path growth |
| Extend rejected / rule tip on illegal move | `reject` | Rate-limit ~150ms so drag spam does not scream |
| Puzzle won (`isWon` / celebrate path) | `clear` | Once per clear |

Flame `ZipGame` stays free of prefs/DI: expose an optional `void Function(SfxId)? onSfx` filled from the Flutter screen that holds `SfxService`.

### Path Words

| Moment | SFX | Notes |
|---|---|---|
| Active path grows by one cell | `tap` | |
| Stroke commits with `targetId` (word completed) | `success` | |
| Failed word attempt (`looksLikeFailedWordAttempt`) | `reject` | |
| All words done → celebrate | `clear` | Once |

Hook inside `PathWordsBloc` at commit / path-grow sites where success vs fail is already known (inject `SfxService` the same way other repos are injected into blocs).

### Sudoku

| Moment | SFX | Notes |
|---|---|---|
| Select an empty / playable cell | `tap` | Soft |
| Place digit with no error indices after place | `success` | |
| Place that introduces or leaves errors | `reject` | |
| Board cleared → celebrating | `clear` | Once |

Hint / notes / erase: silent in v1.

## Mute UX

- Profile settings list: new **Sound effects** row with a `Switch`, placed above Privacy.
- Copy via `AppStrings` (e.g. `profileSoundEffects`).
- **Live for signed-in and signed-out** so mute works before account (signed-out mock should not disable this row).
- Toggle writes prefs immediately and updates `SfxService` cache; no app restart.
- Games always call `play`; the service gates on enabled.

## Failure / edge behavior

- Missing or unloadable clip → log once per id, never throw into gameplay.
- Rapid Zip / Path Words steps → overlapping `tap` allowed; `reject` cooldown ~150ms.
- App backgrounded → one-shots need no special pause; dispose players only with process/service teardown.
- No music ducking or exclusive audio focus requirements beyond defaults.

## Testing

- Unit: `SfxSettingsRepository` round-trip default and set/get.
- Unit: fake/mockable `SfxService` — muted → no player call; load failure → play is safe no-op.
- Bloc / game tests: key transitions invoke expected `SfxId` via mocktail fake (no real audio device).

## Out of scope follow-ups (explicit)

- Word Match SFX
- Music / ambient bed
- Per-game volume or separate music vs SFX toggles
- Custom synthesized tones matching the promo video soundtrack
