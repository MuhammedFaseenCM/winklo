# Blurred Mock Empty State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On Profile and Leaderboard signed-out states, show blurred mock signed-in UI behind a light scrim, with the existing centered sign-in message and button on top.

**Architecture:** Add a shared `BlurredMockEmptyBody` stack widget in `lib/core/widgets/` that blurs an arbitrary `background`, dims with a scrim, and overlays `CenteredMessageBody`. Feature-local mock widgets supply fake Profile / Leaderboard UI. Signed-out call sites only; empty/error and MiniLeaderboard unchanged.

**Tech Stack:** Flutter / Dart (`dart:ui` `ImageFilter`), existing `ZipColors` + `Theme`, `CenteredMessageBody`, `LeaderboardRow`, `UserAvatar`, `flutter_test`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-24-blurred-mock-empty-state-design.md`
- User-facing copy only via `AppStrings` (sign-in strings); fake mock names/times are decorative data
- Promote blur/scrim wrapper to `lib/core/widgets/` (2 features); keep mocks feature-local
- Signed-out only — do not change Leaderboard empty/failure or MiniLeaderboard
- Mock background must be non-interactive (`IgnorePointer`); Sign-in CTA must still work
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/core/widgets/blurred_mock_empty_body.dart` | Stack: blurred background + scrim + `CenteredMessageBody` |
| `test/core/widgets/blurred_mock_empty_body_test.dart` | Message/action visible; background present; taps ignored on mock |
| `lib/features/leaderboard/view/widgets/leaderboard_signed_out_mock.dart` | Fake leaderboard rows for signed-out tease |
| `lib/features/profile/view/widgets/profile_signed_out_mock.dart` | Fake profile form for signed-out tease |
| `lib/features/leaderboard/view/leaderboard_screen.dart` | Signed-out branch uses blurred mock |
| `lib/features/profile/view/profile_screen.dart` | `_SignedOutBody` uses blurred mock |

---

### Task 1: `BlurredMockEmptyBody` widget + tests

**Files:**
- Create: `lib/core/widgets/blurred_mock_empty_body.dart`
- Test: `test/core/widgets/blurred_mock_empty_body_test.dart`

**Interfaces:**
- Consumes: `CenteredMessageBody` from `lib/core/widgets/centered_message_body.dart`; `ZipColors` from `lib/core/theme/app_theme.dart`
- Produces:

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
    this.scrimColor,
  });

  final Widget background;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final double blurSigma;
  final Color? scrimColor;
}
```

- Default `scrimColor`: `ZipColors.ink.withValues(alpha: 0.45)`
- Layer order (bottom → top): blurred+ignored background → full-bleed scrim → `CenteredMessageBody`

- [ ] **Step 1: Write the failing tests**

Create `test/core/widgets/blurred_mock_empty_body_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/core/widgets/blurred_mock_empty_body.dart';
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

  testWidgets('shows message, action, and background; action works', (
    tester,
  ) async {
    var tapped = false;
    await pumpBody(
      tester,
      BlurredMockEmptyBody(
        background: const Text('MockBackground'),
        message: 'Sign in please',
        actionLabel: 'Continue with Google',
        onAction: () => tapped = true,
      ),
    );

    expect(find.text('MockBackground'), findsOneWidget);
    expect(find.text('Sign in please'), findsOneWidget);
    expect(find.byType(CenteredMessageBody), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Continue with Google'),
      findsOneWidget,
    );

    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('ignores pointer events on background', (tester) async {
    var backgroundTapped = false;
    var actionTapped = false;
    await pumpBody(
      tester,
      BlurredMockEmptyBody(
        background: GestureDetector(
          onTap: () => backgroundTapped = true,
          child: const SizedBox(
            width: 200,
            height: 200,
            child: ColoredBox(color: Colors.red),
          ),
        ),
        message: 'Locked',
        actionLabel: 'Sign in',
        onAction: () => actionTapped = true,
      ),
    );

    await tester.tap(find.byType(ColoredBox));
    await tester.pump();
    expect(backgroundTapped, isFalse);

    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(actionTapped, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/widgets/blurred_mock_empty_body_test.dart`

Expected: FAIL — `blurred_mock_empty_body.dart` not found / `BlurredMockEmptyBody` undefined.

- [ ] **Step 3: Write minimal implementation**

Create `lib/core/widgets/blurred_mock_empty_body.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'centered_message_body.dart';

/// Signed-out tease: blurred mock UI + dim scrim + centered message/CTA.
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
    this.scrimColor,
  });

  final Widget background;
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final double blurSigma;
  final Color? scrimColor;

  @override
  Widget build(BuildContext context) {
    final resolvedScrim =
        scrimColor ?? ZipColors.ink.withValues(alpha: 0.45);

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: background,
          ),
        ),
        ColoredBox(color: resolvedScrim),
        CenteredMessageBody(
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
          action: action,
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Format, analyze, run tests**

```bash
dart format lib/core/widgets/blurred_mock_empty_body.dart test/core/widgets/blurred_mock_empty_body_test.dart
dart analyze lib/core/widgets/blurred_mock_empty_body.dart test/core/widgets/blurred_mock_empty_body_test.dart
flutter test test/core/widgets/blurred_mock_empty_body_test.dart
```

Expected: analyze clean; both tests PASS.

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add lib/core/widgets/blurred_mock_empty_body.dart test/core/widgets/blurred_mock_empty_body_test.dart
git commit -m "$(cat <<'EOF'
Add BlurredMockEmptyBody for signed-out teases.

EOF
)"
```

---

### Task 2: Leaderboard signed-out mock + wire screen

**Files:**
- Create: `lib/features/leaderboard/view/widgets/leaderboard_signed_out_mock.dart`
- Modify: `lib/features/leaderboard/view/leaderboard_screen.dart` (signed-out branch only, ~lines 196–201)

**Interfaces:**
- Consumes: `BlurredMockEmptyBody`; `LeaderboardRow`; `LeaderboardEntry`; `AppLayout`; `AppStrings`
- Produces: `class LeaderboardSignedOutMock extends StatelessWidget` with `const LeaderboardSignedOutMock({super.key});`

- [ ] **Step 1: Add mock widget**

Create `lib/features/leaderboard/view/widgets/leaderboard_signed_out_mock.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../domain/entities/leaderboard_entry.dart';
import 'leaderboard_row.dart';

/// Decorative fake rows for signed-out leaderboard tease.
class LeaderboardSignedOutMock extends StatelessWidget {
  const LeaderboardSignedOutMock({super.key});

  static final List<LeaderboardEntry> _entries = [
    LeaderboardEntry(
      uid: 'mock-1',
      displayName: 'Nova',
      timeSeconds: 42,
      updatedAt: DateTime(2026, 1, 1),
      rank: 1,
    ),
    LeaderboardEntry(
      uid: 'mock-2',
      displayName: 'Kai',
      timeSeconds: 58,
      updatedAt: DateTime(2026, 1, 1),
      rank: 2,
    ),
    LeaderboardEntry(
      uid: 'mock-3',
      displayName: 'Remy',
      timeSeconds: 71,
      updatedAt: DateTime(2026, 1, 1),
      rank: 3,
    ),
    LeaderboardEntry(
      uid: 'mock-4',
      displayName: 'Sage',
      timeSeconds: 89,
      updatedAt: DateTime(2026, 1, 1),
      rank: 4,
    ),
    LeaderboardEntry(
      uid: 'mock-5',
      displayName: 'Quin',
      timeSeconds: 104,
      updatedAt: DateTime(2026, 1, 1),
      rank: 5,
    ),
  ];

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: layout.pagePadding,
      itemCount: _entries.length,
      separatorBuilder: (_, _) => SizedBox(height: layout.space(8)),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return LeaderboardRow(
          entry: entry,
          timeLabel: _formatTime(entry.timeSeconds),
          isYou: false,
        );
      },
    );
  }
}
```

- [ ] **Step 2: Wire Leaderboard signed-out branch**

In `lib/features/leaderboard/view/leaderboard_screen.dart`:

1. Add imports:

```dart
import '../../../core/widgets/blurred_mock_empty_body.dart';
import 'widgets/leaderboard_signed_out_mock.dart';
```

2. Replace the `!signedIn` return (currently plain `CenteredMessageBody`) with:

```dart
if (!signedIn) {
  return BlurredMockEmptyBody(
    background: const LeaderboardSignedOutMock(),
    message: AppStrings.leaderboardSignInHint,
    actionLabel: AppStrings.signInWithGoogle,
    onAction: () => showSignInSheet(context),
  );
}
```

Leave `LeaderboardStatus.failure`, empty, and ready list branches unchanged. Keep the existing `centered_message_body.dart` import if still used by failure/empty.

- [ ] **Step 3: Format, analyze, run related tests**

```bash
dart format lib/features/leaderboard/view/widgets/leaderboard_signed_out_mock.dart lib/features/leaderboard/view/leaderboard_screen.dart
dart analyze lib/features/leaderboard/view/widgets/leaderboard_signed_out_mock.dart lib/features/leaderboard/view/leaderboard_screen.dart
flutter test test/features/leaderboard/view/leaderboard_screen_test.dart
```

Expected: analyze clean; existing leaderboard screen tests PASS (update assertions only if they look for a bare `CenteredMessageBody` without the new stack — prefer asserting on sign-in hint text / button).

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add lib/features/leaderboard/view/widgets/leaderboard_signed_out_mock.dart lib/features/leaderboard/view/leaderboard_screen.dart
git commit -m "$(cat <<'EOF'
Show blurred mock rows on signed-out leaderboard.

EOF
)"
```

---

### Task 3: Profile signed-out mock + wire screen

**Files:**
- Create: `lib/features/profile/view/widgets/profile_signed_out_mock.dart`
- Modify: `lib/features/profile/view/profile_screen.dart` (`_SignedOutBody`)

**Interfaces:**
- Consumes: `BlurredMockEmptyBody`; `UserAvatar`; `AppStrings`; `ZipColors`
- Produces: `class ProfileSignedOutMock extends StatelessWidget` with `const ProfileSignedOutMock({super.key});`

- [ ] **Step 1: Add mock widget**

Create `lib/features/profile/view/widgets/profile_signed_out_mock.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/user_avatar.dart';

/// Decorative fake profile form for signed-out tease.
class ProfileSignedOutMock extends StatelessWidget {
  const ProfileSignedOutMock({super.key});

  static const _mockName = 'Player';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: UserAvatar(
              displayName: _mockName,
              radius: 56,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            enabled: false,
            controller: TextEditingController(text: _mockName),
            style: const TextStyle(color: ZipColors.onInk),
            decoration: const InputDecoration(
              labelText: AppStrings.profileEditName,
              hintText: AppStrings.profileNameHint,
            ),
          ),
          const SizedBox(height: 16),
          const FilledButton(
            onPressed: null,
            child: Text(AppStrings.profileSave),
          ),
          const SizedBox(height: 12),
          const OutlinedButton(
            onPressed: null,
            child: Text(AppStrings.signOut),
          ),
        ],
      ),
    );
  }
}
```

**Note:** Creating a `TextEditingController` inside `build` is normally wrong for live forms, but this mock is static, never focused, and covered by `IgnorePointer`. Prefer a `StatelessWidget` with an initial-value approach that does not leak controllers:

Use a disabled field without a long-lived controller:

```dart
TextFormField(
  initialValue: _mockName,
  enabled: false,
  style: const TextStyle(color: ZipColors.onInk),
  decoration: const InputDecoration(
    labelText: AppStrings.profileEditName,
    hintText: AppStrings.profileNameHint,
  ),
),
```

Use the `TextFormField` version in the implementation (not `TextEditingController` in `build`).

- [ ] **Step 2: Wire Profile `_SignedOutBody`**

In `lib/features/profile/view/profile_screen.dart`:

1. Add imports:

```dart
import '../../../core/widgets/blurred_mock_empty_body.dart';
import 'widgets/profile_signed_out_mock.dart';
```

2. Replace `_SignedOutBody.build` body with:

```dart
@override
Widget build(BuildContext context) {
  return BlurredMockEmptyBody(
    background: const ProfileSignedOutMock(),
    message: AppStrings.profileSignedOutBody,
    actionLabel: AppStrings.signInWithGoogle,
    onAction: () => showSignInSheet(context),
  );
}
```

Remove unused `centered_message_body.dart` import if nothing else in the file needs it.

- [ ] **Step 3: Format, analyze, smoke**

```bash
dart format lib/features/profile/view/widgets/profile_signed_out_mock.dart lib/features/profile/view/profile_screen.dart
dart analyze lib/features/profile/view/widgets/profile_signed_out_mock.dart lib/features/profile/view/profile_screen.dart lib/core/widgets/blurred_mock_empty_body.dart
flutter test test/core/widgets/blurred_mock_empty_body_test.dart
```

If profile screen widget tests exist, run them too:

```bash
flutter test test/features/profile/
```

Expected: analyze clean; tests PASS.

Manual: open Profile and Leaderboard while signed out — blurred mock visible, dimmed, Sign-in button works; empty/error leaderboard still plain `CenteredMessageBody`.

- [ ] **Step 4: Commit** (only if user asked)

```bash
git add lib/features/profile/view/widgets/profile_signed_out_mock.dart lib/features/profile/view/profile_screen.dart
git commit -m "$(cat <<'EOF'
Show blurred mock profile on signed-out screen.

EOF
)"
```

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Shared blur + scrim + `CenteredMessageBody` stack | Task 1 |
| Leaderboard mock rows + signed-out wire | Task 2 |
| Profile mock form + signed-out wire | Task 3 |
| Empty / error / MiniLeaderboard unchanged | Task 2 leaves those branches; Task 3 does not touch MiniLeaderboard |
| Non-interactive mock; Sign-in works | Task 1 tests |
| Decorative mock names (not AppStrings product copy) | Task 2 mock names hardcoded |

## Plan self-review

- No TBD/placeholder steps; full code for widget, mocks, and call sites
- Types consistent: `BlurredMockEmptyBody` API matches Tasks 2–3 call sites
- Profile mock uses `TextFormField(initialValue:)` to avoid controller-in-build leak
