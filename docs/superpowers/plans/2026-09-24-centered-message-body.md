# Centered Message Body Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract a shared `CenteredMessageBody` widget and use it so Profile signed-out content is centered like Leaderboard, with optional title and style/action customization.

**Architecture:** Add a presentation-only widget under `lib/core/widgets/`. Replace Profile `_SignedOutBody` layout and the duplicated `_MessageBody` in Leaderboard + MiniLeaderboard with that widget. No Cubit/Bloc deps; callers pass strings and callbacks.

**Tech Stack:** Flutter / Dart, existing `ZipColors` + `Theme`, `flutter_test`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-24-centered-message-body-design.md`
- User-facing copy only via `AppStrings` (widget accepts `String` params; screens pass `AppStrings.*`)
- Promote to `lib/core/widgets/` because 2+ features use it
- Do not change signed-in Profile, Sign-in sheet, or theme tokens
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/core/widgets/centered_message_body.dart` | Shared centered empty-state (title / message / action) |
| `test/core/widgets/centered_message_body_test.dart` | Widget behavior + customization |
| `lib/features/profile/view/profile_screen.dart` | Signed-out body uses shared widget |
| `lib/features/leaderboard/view/leaderboard_screen.dart` | Replace private `_MessageBody` |
| `lib/features/results/view/mini_leaderboard_panel.dart` | Replace private `_MessageBody` |

---

### Task 1: `CenteredMessageBody` widget + tests

**Files:**
- Create: `lib/core/widgets/centered_message_body.dart`
- Test: `test/core/widgets/centered_message_body_test.dart`

**Interfaces:**
- Produces:

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

  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final double titleSpacing;
  final double messageSpacing;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final TextAlign textAlign;
}
```

- Action resolution: `action` wins; else `FilledButton` when both `actionLabel` and `onAction` are non-null; else no action.
- Default styles: title → `Theme.textTheme.titleLarge` + `ZipColors.onInk`; message → `bodyLarge` + `ZipColors.inkSoft`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/centered_message_body.dart';

void main() {
  Future<void> pumpBody(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('centers title, message, and default action', (tester) async {
    var tapped = false;
    await pumpBody(
      tester,
      CenteredMessageBody(
        title: 'Your profile',
        message: 'Sign in please',
        actionLabel: 'Continue with Google',
        onAction: () => tapped = true,
      ),
    );

    expect(find.text('Your profile'), findsOneWidget);
    expect(find.text('Sign in please'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('omits title and action when not provided', (tester) async {
    await pumpBody(
      tester,
      const CenteredMessageBody(message: 'Empty board'),
    );

    expect(find.text('Empty board'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('custom action replaces default button', (tester) async {
    await pumpBody(
      tester,
      CenteredMessageBody(
        message: 'Retry?',
        actionLabel: 'Unused',
        onAction: () {},
        action: TextButton(onPressed: () {}, child: const Text('Custom')),
      ),
    );

    expect(find.text('Custom'), findsOneWidget);
    expect(find.text('Unused'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/widgets/centered_message_body_test.dart`

Expected: FAIL — `centered_message_body.dart` does not exist / `CenteredMessageBody` not found.

- [ ] **Step 3: Implement the widget**

Create `lib/core/widgets/centered_message_body.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Centered empty-state: optional title, message, and optional action.
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

  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final EdgeInsetsGeometry padding;
  final double titleSpacing;
  final double messageSpacing;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedTitleStyle =
        titleStyle ??
        theme.textTheme.titleLarge?.copyWith(color: ZipColors.onInk);
    final resolvedMessageStyle =
        messageStyle ??
        theme.textTheme.bodyLarge?.copyWith(color: ZipColors.inkSoft);

    final Widget? resolvedAction =
        action ??
        (actionLabel != null && onAction != null
            ? FilledButton(onPressed: onAction, child: Text(actionLabel!))
            : null);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(title!, textAlign: textAlign, style: resolvedTitleStyle),
              SizedBox(height: titleSpacing),
            ],
            Text(message, textAlign: textAlign, style: resolvedMessageStyle),
            if (resolvedAction != null) ...[
              SizedBox(height: messageSpacing),
              resolvedAction,
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Format and run tests**

Run:

```bash
dart format lib/core/widgets/centered_message_body.dart test/core/widgets/centered_message_body_test.dart
flutter test test/core/widgets/centered_message_body_test.dart
dart analyze lib/core/widgets/centered_message_body.dart test/core/widgets/centered_message_body_test.dart
```

Expected: format clean; tests PASS; analyze no issues.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add lib/core/widgets/centered_message_body.dart test/core/widgets/centered_message_body_test.dart
git commit -m "$(cat <<'EOF'
Add shared CenteredMessageBody empty-state widget.

EOF
)"
```

---

### Task 2: Wire Profile, Leaderboard, and MiniLeaderboard

**Files:**
- Modify: `lib/features/profile/view/profile_screen.dart` (`_SignedOutBody`)
- Modify: `lib/features/leaderboard/view/leaderboard_screen.dart` (replace `_MessageBody`)
- Modify: `lib/features/results/view/mini_leaderboard_panel.dart` (replace `_MessageBody`)

**Interfaces:**
- Consumes: `CenteredMessageBody` from Task 1 (exact constructor above)
- Produces: no new public APIs; call sites only

- [ ] **Step 1: Update Profile signed-out body**

In `lib/features/profile/view/profile_screen.dart`:

1. Add import:

```dart
import '../../../core/widgets/centered_message_body.dart';
```

2. Replace `_SignedOutBody.build` with:

```dart
@override
Widget build(BuildContext context) {
  return CenteredMessageBody(
    title: AppStrings.profileSignedOutTitle,
    message: AppStrings.profileSignedOutBody,
    actionLabel: AppStrings.signInWithGoogle,
    onAction: () => showSignInSheet(context),
  );
}
```

Keep the `_SignedOutBody` private class wrapper if desired (thin delegate), or inline `const`/`CenteredMessageBody` at the call site in `ProfileScreen` — prefer keeping `_SignedOutBody` as a one-liner wrapper for readability.

- [ ] **Step 2: Update Leaderboard**

In `lib/features/leaderboard/view/leaderboard_screen.dart`:

1. Add import:

```dart
import '../../../core/widgets/centered_message_body.dart';
```

2. Replace every `_MessageBody(...)` with `CenteredMessageBody(...)` using the same `message` / `actionLabel` / `onAction` arguments.

3. Delete the private `_MessageBody` class at the bottom of the file (lines that define `class _MessageBody`).

Call-site mapping (keep existing strings/callbacks):

```dart
CenteredMessageBody(
  message: AppStrings.leaderboardSignInHint,
  actionLabel: AppStrings.signInWithGoogle,
  onAction: () => showSignInSheet(context),
)

CenteredMessageBody(
  message: state.error ?? AppStrings.leaderboardFailed,
  actionLabel: AppStrings.retry,
  onAction: () => context.read<LeaderboardCubit>().retry(),
)

const CenteredMessageBody(
  message: AppStrings.leaderboardEmpty,
)
```

- [ ] **Step 3: Update MiniLeaderboard**

In `lib/features/results/view/mini_leaderboard_panel.dart`:

1. Add import:

```dart
import '../../../core/widgets/centered_message_body.dart';
```

2. Replace every `_MessageBody(...)` with `CenteredMessageBody(...)` (same argument mapping as Leaderboard).

3. Delete the private `_MessageBody` class.

- [ ] **Step 4: Format, analyze, and run related tests**

Run:

```bash
dart format \
  lib/features/profile/view/profile_screen.dart \
  lib/features/leaderboard/view/leaderboard_screen.dart \
  lib/features/results/view/mini_leaderboard_panel.dart

dart analyze \
  lib/core/widgets/centered_message_body.dart \
  lib/features/profile/view/profile_screen.dart \
  lib/features/leaderboard/view/leaderboard_screen.dart \
  lib/features/results/view/mini_leaderboard_panel.dart

flutter test \
  test/core/widgets/centered_message_body_test.dart \
  test/features/leaderboard/view/leaderboard_screen_test.dart
```

Expected: format clean; analyze clean; tests PASS.

Manual check: open Profile while signed out — title, body, and Google button are centered (same visual pattern as Leaderboard signed-out).

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add \
  lib/core/widgets/centered_message_body.dart \
  test/core/widgets/centered_message_body_test.dart \
  lib/features/profile/view/profile_screen.dart \
  lib/features/leaderboard/view/leaderboard_screen.dart \
  lib/features/results/view/mini_leaderboard_panel.dart
git commit -m "$(cat <<'EOF'
Center profile signed-out state via shared CenteredMessageBody.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Centered like Leaderboard | Task 1 layout + Task 2 Profile |
| Optional title | Task 1 API + Task 2 Profile |
| Required message + optional action | Task 1 |
| Style/padding/spacing/textAlign/custom action | Task 1 API |
| `lib/core/widgets/` | Task 1 |
| Profile / Leaderboard / MiniLeaderboard call sites | Task 2 |
| Remove duplicated `_MessageBody` | Task 2 |
| Copy via `AppStrings` | Task 2 |
| Out of scope: signed-in Profile, sign-in sheet, new tokens | (not in plan) |
