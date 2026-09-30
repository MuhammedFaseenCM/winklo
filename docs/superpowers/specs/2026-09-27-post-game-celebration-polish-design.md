# Post-game celebration polish — design

Date: 2026-09-27  
Status: approved for implementation

## Goal

Make Zip / Path Words guest results feel like a **win**, not a static scorecard — staged motion + ember burst + haptics — while flipping CTA hierarchy so **Save to board** is the exciting primary and **Back home** stays a one-tap exit (no blocker).

## Product decisions

| Topic | Choice |
|-------|--------|
| Scope | Guest Zip / Path Words results path (`_CelebrateAndClaimResults`) |
| Motion approach | In-app kit — `flutter_animate` + small CustomPainter ember burst (no new packages) |
| CTA hierarchy (guest) | Primary: Save `{time}` to today’s board · Secondary: Back home |
| Signed-in results | Same celebration entrance; keep mini board; no save CTA |
| Leave | Always one tap via Back home — never gated |
| Sound | Out of scope |
| Word Match / other games | Unchanged |
| Leaderboard tab | Unchanged |

Builds on [celebrate + soft claim](2026-09-27-post-game-celebrate-soft-claim-design.md).

## Approach

**Motion kit + CTA flip.**

### Entrance sequence (~1.2s)

1. ZipMark scale-in + fade  
2. Title (“Puzzle cleared!”) fade/slide  
3. Celebration card fade/slide  
4. Time **counts up** from `0:00` to final `m:ss` (~500–700ms, easeOut)  
5. Points / PB / streak badges **spring** in (staggered)  
6. Short **ember spark burst** around the time digits (one-shot, ~600–800ms)  
7. Light **haptic** once when time lands (or on first frame of burst)

Buttons appear after the card (or with slight delay) so motion isn’t competing with taps.

### CTA hierarchy (guest)

```
[ Save 0:48 to today’s board ]   ← ZipPrimaryButton (ember)
        Back home                ← TextButton
```

Copy unchanged (`saveTimeToBoard`, `backHome`). Sign-in sheet claim copy unchanged.

### Signed-in

Same entrance on celebration card; then existing `MiniLeaderboardPanel` below. No save CTA.

## Architecture

```
_CelebrateAndClaimResults
  → celebration entrance (animate + count-up + burst + haptic)
  → guest: Save primary, Back home secondary
  → signed-in: MiniLeaderboardPanel
```

New small pieces (feature-local unless reused):

- `_CountingPlayTime` — animates `0` → `timeSeconds`, displays via `AppStrings.formatPlayTime`
- `_EmberBurst` — CustomPainter one-shot sparks (ember / onInk colors), dispose after done
- Optional extract of celebration card stay as `_ResultsCelebrationCard`

Prefer keeping widgets under `lib/features/results/view/` if files grow.

## Out of scope

- New pub packages (confetti, Lottie, Rive)
- Audio / music
- Exact “you’d be #N” teaser
- Redesign of generic (non-Zip/Path Words) results card beyond shared card reuse already done
- Changing soft-claim sign-in / submit behavior

## Testing

- Guest results: Save CTA is primary (ZipPrimaryButton / ember filled); Back home is text-style secondary  
- Guest can still leave via Back home without signing in  
- Time eventually shows final formatted value (count-up may be skipped or instant in tests via pump settle)  
- Soft claim → sheet → submit path still works  
- Signed-in: celebration + mini board; no save CTA  
- Widget tests: prefer `pumpAndSettle` / advance time; avoid brittle frame-by-frame animation asserts

## Error handling

| Case | Behavior |
|------|----------|
| Reduced motion (if detectable later) | Out of scope this pass — always play short sequence |
| Haptics unsupported | No-op |
| Burst paint error | Fail soft; celebration text still shows |
