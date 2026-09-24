# Bottom Nav Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the full-bleed stock `NavigationBar` with a floating dock using Material-style Home / Trophy / Person icons and ember active treatment.

**Architecture:** Extract `FloatingNavDock` under `features/dashboard/view/widgets/`. `DashboardShell` keeps `StatefulNavigationShell` wiring and passes `selectedIndex` + `onDestinationSelected`. No router or tab-set changes. Use Flutter `Icons` outlined/filled glyphs (`home`, `emoji_events`, `person`) — they match the approved Material Symbols look for these three marks without adding a package (YAGNI). Revisit `material_symbols_icons` only if visual QA rejects the stock glyphs.

**Tech Stack:** Flutter / Dart, existing `ZipColors`, `go_router` shell, `flutter_test`.

## Global Constraints

- Follow spec: `docs/superpowers/specs/2026-09-24-bottom-nav-polish-design.md`
- Labels only via `AppStrings` (`navHome`, `navLeaderboard`, `navProfile`)
- Floating dock: horizontal inset 12–16, radius 20–24, `ZipColors.paper`/`wall` fill, quiet outline, soft shadow
- Active: ember label + `emberSoft` pill behind icon; idle: `inkSoft`
- Trophy for Leaderboard (`Icons.emoji_events_outlined` / `Icons.emoji_events`)
- No route / tab-count / Profile / Home content changes
- Games/results remain outside shell (no bar)
- Analyze with timed `dart analyze <changed files>` — never MCP `analyze_files`
- Run `dart format` on touched Dart files
- Commits only when the user asks (skip commit steps unless explicitly requested)

---

## File structure map

| Path | Responsibility |
|------|----------------|
| `lib/features/dashboard/view/widgets/floating_nav_dock.dart` | Capsule bar + three destinations |
| `lib/features/dashboard/view/dashboard_shell.dart` | Wire dock to `navigationShell` |
| `test/features/dashboard/floating_nav_dock_test.dart` | Dock chrome + selection callbacks |
| `test/features/dashboard/dashboard_shell_test.dart` | Keep tab switch; assert dock present |

---

### Task 1: `FloatingNavDock` widget

**Files:**
- Create: `lib/features/dashboard/view/widgets/floating_nav_dock.dart`
- Test: `test/features/dashboard/floating_nav_dock_test.dart`

**Interfaces:**
- Produces:

```dart
class FloatingNavDock extends StatelessWidget {
  const FloatingNavDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
}
```

- Destinations (fixed order):
  - 0: `AppStrings.navHome` — `Icons.home_outlined` / `Icons.home`
  - 1: `AppStrings.navLeaderboard` — `Icons.emoji_events_outlined` / `Icons.emoji_events`
  - 2: `AppStrings.navProfile` — `Icons.person_outline` / `Icons.person`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/strings/app_strings.dart';
import 'package:winklo/core/theme/app_theme.dart';
import 'package:winklo/features/dashboard/view/widgets/floating_nav_dock.dart';

void main() {
  testWidgets('shows three labels and reports taps', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 0,
            onDestinationSelected: taps.add,
          ),
        ),
      ),
    );

    expect(find.text(AppStrings.navHome), findsOneWidget);
    expect(find.text(AppStrings.navLeaderboard), findsOneWidget);
    expect(find.text(AppStrings.navProfile), findsOneWidget);

    await tester.tap(find.text(AppStrings.navLeaderboard));
    await tester.pump();
    expect(taps, [1]);
  });

  testWidgets('dock is horizontally inset from screen edges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );

    final dock = tester.getRect(find.byKey(const Key('floating_nav_dock')));
    final screen = tester.getRect(find.byType(Scaffold));
    expect(dock.left, greaterThan(screen.left + 8));
    expect(dock.right, lessThan(screen.right - 8));
  });

  testWidgets('leaderboard uses trophy icons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          bottomNavigationBar: FloatingNavDock(
            selectedIndex: 1,
            onDestinationSelected: (_) {},
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.emoji_events), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

Run: `flutter test test/features/dashboard/floating_nav_dock_test.dart`  
Expected: FAIL (missing library / widget)

- [ ] **Step 3: Implement `FloatingNavDock`**

```dart
import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

class FloatingNavDock extends StatelessWidget {
  const FloatingNavDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = <_DockDestination>[
    _DockDestination(
      label: AppStrings.navHome,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _DockDestination(
      label: AppStrings.navLeaderboard,
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
    ),
    _DockDestination(
      label: AppStrings.navProfile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Material(
        key: const Key('floating_nav_dock'),
        color: ZipColors.paper,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: ZipColors.outlineQuiet),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < _destinations.length; i++)
                Expanded(
                  child: _DockItem(
                    destination: _destinations[i],
                    selected: selectedIndex == i,
                    onTap: () => onDestinationSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockDestination {
  const _DockDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _DockItem extends StatelessWidget {
  const _DockItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _DockDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ZipColors.ember : ZipColors.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 44,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? ZipColors.emberSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              destination.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Adjust imports/paths if the feature folder depth differs; keep visual tokens exact.

- [ ] **Step 4: Run tests — expect PASS**

Run: `flutter test test/features/dashboard/floating_nav_dock_test.dart`  
Then: `dart analyze lib/features/dashboard/view/widgets/floating_nav_dock.dart`  
Then: `dart format lib/features/dashboard/view/widgets/floating_nav_dock.dart test/features/dashboard/floating_nav_dock_test.dart`

- [ ] **Step 5: Commit** (only if user asked)

```bash
git add lib/features/dashboard/view/widgets/floating_nav_dock.dart test/features/dashboard/floating_nav_dock_test.dart
git commit -m "feat: add floating nav dock widget"
```

---

### Task 2: Wire dock into `DashboardShell`

**Files:**
- Modify: `lib/features/dashboard/view/dashboard_shell.dart`
- Modify: `test/features/dashboard/dashboard_shell_test.dart`

**Interfaces:**
- Consumes: `FloatingNavDock(selectedIndex:, onDestinationSelected:)`
- Keep existing `goBranch` behavior:

```dart
onDestinationSelected: (index) {
  navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );
},
```

- [ ] **Step 1: Extend shell test**

Add to `dashboard_shell_test.dart` after existing expectations:

```dart
expect(find.byKey(const Key('floating_nav_dock')), findsOneWidget);
expect(find.byType(NavigationBar), findsNothing);
```

- [ ] **Step 2: Run — expect FAIL** on `floating_nav_dock` / still finds `NavigationBar`

Run: `flutter test test/features/dashboard/dashboard_shell_test.dart`

- [ ] **Step 3: Replace `NavigationBar` in `DashboardShell`**

```dart
import 'widgets/floating_nav_dock.dart';

// ...
bottomNavigationBar: FloatingNavDock(
  selectedIndex: navigationShell.currentIndex,
  onDestinationSelected: (index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  },
),
```

Remove unused `ZipColors` import from shell if it becomes unused.

- [ ] **Step 4: Run all dashboard tests + analyze**

```bash
flutter test test/features/dashboard/
dart analyze lib/features/dashboard/
dart format lib/features/dashboard/ test/features/dashboard/
```

Expected: all PASS / no issues

- [ ] **Step 5: Manual smoke (checklist)**

1. Floating capsule inset on Home / Leaderboard / Profile  
2. Trophy icon on Leaderboard tab  
3. Active ember pill + label  
4. Open Zip / Path Words — no bottom dock  
5. Safe area OK on notched device/emulator  

- [ ] **Step 6: Commit** (only if user asked)

```bash
git commit -m "feat: use floating dock for dashboard bottom nav"
```

---

## Spec coverage (self-review)

| Spec item | Task |
|-----------|------|
| Floating dock inset + radius + fill/border/shadow | 1 |
| Material Home / Trophy / Person outlined→filled | 1 |
| Ember active + emberSoft pill | 1 |
| AppStrings labels | 1 |
| Wire to `goBranch` / no route changes | 2 |
| Tests: labels, inset, no full-bleed `NavigationBar` | 1–2 |
| No `material_symbols_icons` unless QA rejects Icons | Global (YAGNI) |

**Type consistency:** `FloatingNavDock` key `floating_nav_dock`; destinations indices 0/1/2 match shell branches.
