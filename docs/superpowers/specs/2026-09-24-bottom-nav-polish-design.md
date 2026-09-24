# Bottom navigation polish — design

Date: 2026-09-24  
Status: approved for implementation

## Goal

Upgrade the Dashboard bottom navigation from stock Material Icons on a full-bleed `NavigationBar` to **Material Symbols** icons (trophy for Leaderboard) on a **floating dock** that matches Winklo’s ink & ember visual language.

## Product decisions

| Topic | Choice |
|-------|--------|
| Icon set | Material Symbols (rounded / outlined → filled when selected) |
| Home | Home glyph |
| Leaderboard | Trophy (`emoji_events` / Symbols equivalent) |
| Profile | Person glyph |
| Bar chrome | Floating dock (inset capsule over canvas) |
| Active state | Ember label + soft ember pill behind icon |
| Labels | Unchanged: Home / Leaderboard / Profile via `AppStrings` |
| Scope | Shell chrome + icons only — no route or tab-set changes |

## Approach

**Custom floating dock wrapping the existing `StatefulNavigationShell` destinations** (chosen over restyling stock full-bleed `NavigationBar` alone, and over custom SVG brand marks): keeps Material industry-standard glyphs while delivering the approved capsule layout.

Prefer a small curated set of Material Icons / Material Symbols that match the Symbols look. If the stock `Icons.*` glyphs are insufficiently “Symbols-like,” add `material_symbols_icons` (or equivalent) and use rounded variants.

## Architecture

```
DashboardShell
  Scaffold
    body: navigationShell
    bottomNavigationBar: SafeArea → padding → FloatingNavDock
      destinations: Home | Leaderboard (trophy) | Profile
      onSelect → navigationShell.goBranch
```

### Files (expected)

| Path | Change |
|------|--------|
| `lib/features/dashboard/view/dashboard_shell.dart` | Replace stock `NavigationBar` with floating dock |
| `lib/features/dashboard/view/widgets/floating_nav_dock.dart` | Capsule bar + destination items (extract if shell grows) |
| `lib/core/theme/app_theme.dart` | Optional shared dock tokens (radius, shadow) if reused |
| `test/features/dashboard/dashboard_shell_test.dart` | Assert dock + labels still present; icons smoke if useful |
| `pubspec.yaml` | Only if a Symbols package is required |

No router, Profile, or Home content changes.

## Visual spec

### Floating dock

- Horizontal inset ≈ 12–16 logical px; bottom inset respects `SafeArea`
- Corner radius ≈ 20–24
- Fill: `ZipColors.paper` or `wall` (raised vs canvas `ink`)
- Border: `ZipColors.outlineQuiet` / `outline` at low emphasis
- Soft elevation / shadow (dark-theme appropriate, not multi-layer glow)
- Content behind side margins of the dock remains the scaffold body (floating feel)

### Destinations

| Index | Label (`AppStrings`) | Idle icon | Selected icon |
|-------|----------------------|-----------|---------------|
| 0 | `navHome` | home outlined | home filled |
| 1 | `navLeaderboard` | trophy outlined | trophy filled |
| 2 | `navProfile` | person outlined | person filled |

- Selected: icon + label use `ZipColors.ember`; icon sits on `ZipColors.emberSoft` pill
- Unselected: `ZipColors.inkSoft`
- Hit target: comfortable tap area (≥ 48px height for the row)

### Out of scope

- Changing tab count or routes
- Custom Winklo SVG marks
- Animating complex shared-axis transitions beyond a simple indicator cross-fade/scale if cheap
- Bottom nav on game/results screens (already absent)

## Testing

- Existing `dashboard_shell_test` still finds three nav labels and can switch Profile
- Widget test: dock is inset (not full-bleed edge-to-edge) — e.g. find padded container / non–full-width bar if practical
- Manual: Home / Leaderboard / Profile selection, safe area on notched devices, games still hide the bar

## Relation to prior work

Builds on `docs/superpowers/specs/2026-09-24-dashboard-bottom-nav-design.md` (shell tabs). This spec only polishes presentation.
