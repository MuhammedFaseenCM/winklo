# Blurred mock empty state — design

Date: 2026-09-24  
Status: approved for implementation

## Goal

On **Profile** and **Leaderboard** signed-out states, show a blurred tease of the real signed-in UI behind a light dim, with the existing centered sign-in message and button on top.

## Product decisions

| Topic | Choice |
|-------|--------|
| Which states | Signed-out only (Profile + Leaderboard) |
| Mock content | Reuse real signed-in UI widgets with fake data |
| Overlay | Blur + light dim/scrim behind the message |
| Structure | Shared stack wrapper in `core/widgets`; feature-local mocks |
| MiniLeaderboard | Out of scope |
| Empty / error Leaderboard | Unchanged |

## Approach

Add **`BlurredMockEmptyBody`** in `lib/core/widgets/`. It stacks:

1. `background` — `IgnorePointer` + `ImageFiltered` blur  
2. Full-bleed light scrim (`ZipColors.ink` at ~40–50% opacity)  
3. Existing `CenteredMessageBody` (title / message / action)

Profile and Leaderboard each pass a feature-local mock widget as `background`. Sign-in copy and CTA stay as today via `AppStrings` + `showSignInSheet`.

## Shared widget API

```dart
class BlurredMockEmptyBody extends StatelessWidget {
  const BlurredMockEmptyBody({
    super.key,
    required this.background,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.action,
    this.blurSigma = 10,
    this.scrimColor, // default: ZipColors.ink @ ~0.45 alpha
  });
}
```

### Behavior

- Renders a `Stack` that fills the available space (`fit: StackFit.expand` via parent `Expanded` / full body).
- Background is non-interactive (`IgnorePointer`) and decorative (exclude from semantics where practical).
- Blur defaults ~8–12 sigma (`blurSigma`).
- Scrim sits between mock and message so the CTA stays readable while the tease remains visible.
- Message layer delegates to `CenteredMessageBody` with the same title / message / action knobs callers already use.

## Feature mocks

### Leaderboard

- Path: `lib/features/leaderboard/view/widgets/` (e.g. `leaderboard_signed_out_mock.dart`)
- Short list of ~4–5 `LeaderboardRow`s with hardcoded fake `LeaderboardEntry` values (ranks, names, times; medals for 1–3).
- No Cubit; pure presentation; same padding rhythm as the real list.
- Entire mock ignored for pointer events by the shared wrapper.

### Profile

- Path: `lib/features/profile/view/widgets/` (e.g. `profile_signed_out_mock.dart`)
- Static recreation of signed-in layout: avatar, name field with a fake name, Save + Sign out buttons.
- Visually matches `_SignedInBody`; no Cubit wiring; controls do nothing (and are covered by `IgnorePointer`).

### Copy

- Sign-in strings remain in `AppStrings`.
- Fake display names / times are decorative mock data, not product copy.

## Call sites

| Screen | Change |
|--------|--------|
| Profile `_SignedOutBody` | Wrap with `BlurredMockEmptyBody` + profile mock |
| Leaderboard `!signedIn` branch | Wrap with `BlurredMockEmptyBody` + leaderboard mock |
| Leaderboard empty / failure | No change |
| MiniLeaderboard | No change |

## Out of scope

- MiniLeaderboard signed-out treatment
- Leaderboard empty or error states
- Changing signed-in Profile or live Leaderboard list behavior
- New theme tokens beyond existing `ZipColors` / `Theme` text styles
- Screenshot / image-based mock assets

## Testing

- Widget test for `BlurredMockEmptyBody`: message (and action when provided) visible; background child present in the tree.
- Rely on existing screen tests for signed-out smoke where present.
- Manual check: blur + scrim contrast and Sign-in still opens the sheet.

## Success criteria

- Signed-out Profile and Leaderboard show blurred mock UI + dim + centered sign-in CTA
- Mock is non-interactive; Sign in still works
- Empty / error Leaderboard unchanged
- Blur / scrim live in one shared core widget; mocks stay feature-local
