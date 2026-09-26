# Centered message body — design

Date: 2026-09-24  
Status: approved for implementation

## Goal

Center the Profile signed-out empty state the same way Leaderboard does, and extract a **shared, customizable** empty-state widget used by Profile, Leaderboard, and MiniLeaderboard.

## Product decisions

| Topic | Choice |
|-------|--------|
| Alignment | Horizontally and vertically centered (match Leaderboard `_MessageBody`) |
| Title | Optional — Profile keeps “Your profile” + body |
| Message | Required |
| Action | Optional label + callback (FilledButton by default) |
| Customization | Override styles, padding, spacing, text align, and/or replace the action with a custom widget |
| Location | `lib/core/widgets/` (used by 2+ features) |

## Approach

Promote the duplicated `_MessageBody` pattern into **`CenteredMessageBody`** with optional title and style knobs. Profile, Leaderboard, and MiniLeaderboard all call it; remove private `_MessageBody` / `_SignedOutBody` layout copies.

## Widget API

```dart
class CenteredMessageBody extends StatelessWidget {
  const CenteredMessageBody({
    super.key,
    this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.action,
    this.padding = const EdgeInsets.all(24),
    this.titleSpacing = 12,
    this.messageSpacing = 16,
    this.titleStyle,
    this.messageStyle,
    this.textAlign = TextAlign.center,
  });
}
```

### Behavior

- Renders a `Center` → padded `Column` (`mainAxisSize: min`).
- Shows `title` when non-null (Profile signed-out).
- Always shows `message`.
- Action resolution:
  1. If `action` is non-null → use it.
  2. Else if `actionLabel` and `onAction` are both non-null → default `FilledButton`.
  3. Else → no action.
- Defaults: `title` uses `titleLarge` + `ZipColors.onInk`; `message` uses `bodyLarge` + `ZipColors.inkSoft`; both respect `textAlign`.

### Call sites

| Screen | title | message | action |
|--------|-------|---------|--------|
| Profile signed-out | `profileSignedOutTitle` | `profileSignedOutBody` | Sign in → `showSignInSheet` |
| Leaderboard signed-out / empty / error | — | existing strings | Sign in / Retry when present |
| MiniLeaderboard signed-out / empty / error | — | existing strings | Sign in / Retry when present |

Copy stays in `AppStrings`; the widget takes strings as parameters.

## Out of scope

- Changing signed-in Profile layout
- Changing Sign-in sheet layout
- New theming tokens beyond existing `ZipColors` / `Theme` text styles
- Widget tests required only if the plan adds them; smoke via existing screen tests is enough for this pass

## Success criteria

- Profile signed-out content is centered like Leaderboard
- One shared widget in `core/widgets`; no duplicated `_MessageBody`
- Callers can customize title/styles/action without forking the layout
