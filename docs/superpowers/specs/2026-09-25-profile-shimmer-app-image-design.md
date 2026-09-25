# Profile shimmer, edit badge, and AppImage

**Date:** 2026-09-25  
**Status:** Approved  
**Approach:** Shared shimmer + AppImage primitives (`shimmer`, `cached_network_image`, `flutter_svg`)

## Problem

1. After app restart while already signed in, Profile briefly shows the signed-out / sign-in mock because `AuthStatus.unknown` has `user == null` and the screen treats any null user as signed out.
2. The profile avatar has no edit affordance; users only discover tap-to-edit by accident.
3. Network images use bare `NetworkImage` / `Image.asset` with no shared caching, placeholders, or SVG support.
4. There is no reusable shimmer skeleton for loading states across the app.

## Goals

- Show a profile-shaped shimmer while auth is restoring and whenever profile data is refreshing (including pull-to-refresh).
- Add an edit icon badge on the avatar via `Stack`.
- Introduce reusable shimmer primitives under `core/widgets`.
- Introduce a dedicated `AppImage` widget for network / asset / file / memory images, including SVG, and route `UserAvatar` through it.
- Keep signed-out UX unchanged once auth has resolved to `signedOut`.

## Non-goals (v1)

- Full-screen lightbox / zoom gallery.
- Lottie, PDF, or HEIC-specific pipelines.
- Disk cache for network SVGs beyond what `flutter_svg` / HTTP provide by default.
- Changing Home / Leaderboard signed-out patterns (unless they share `AppImage` via `UserAvatar` only).

## Auth / Profile body matrix

| `AuthStatus` | Profile body |
|---|---|
| `unknown` | `ProfileShimmer` (no CTA, no blur mock) |
| `signedOut` | Existing `BlurredMockEmptyBody` + sign-in |
| `signedIn` | `_SignedInBody` (edit badge, pull-to-refresh) |
| `signingIn` / `failure` | Unchanged (sheet / snackbar flows) |

**Rule:** Never show the signed-out mock while auth is still restoring.

## Avatar edit badge

On the signed-in profile avatar:

- Wrap `UserAvatar` in a `Stack`.
- Bottom-right: small circular badge with `Icons.edit`, themed for dark ink / wall contrast (~28–32px diameter).
- Entire stack remains tappable → existing `AvatarEditSheet`.
- Semantics label remains `AppStrings.profileEditAvatar`.
- Avatar radius stays 56.

## Shared shimmer

### Dependencies

- `shimmer: ^4.0.0`

### Core widgets (`lib/core/widgets/app_shimmer.dart`)

- `AppShimmer` — wraps children with theme-aware base/highlight colors suited to `ZipColors.ink`.
- `AppShimmerBox` — rounded rect placeholder (`width`, `height`, `borderRadius`).
- `AppShimmerCircle` — circle placeholder (`radius`).

### Profile layout (`lib/features/profile/view/widgets/profile_shimmer.dart`)

Mirrors signed-in profile:

1. Centered circle (r=56)
2. Name bar
3. Subtitle / “edit display name” bar
4. Settings card block

Uses the same horizontal padding as `AppLayout.pagePadding`.

### When shimmer is shown

1. `AuthStatus.unknown`
2. `ProfileStatus.refreshing` (pull-to-refresh)

**Not** shown on first signed-in frame when `fallbackUser` is available and the user is not refreshing — avoid a flash of skeleton after auth resolves.

### Refresh

- Wrap signed-in scroll body in `RefreshIndicator`.
- `ProfileCubit.refresh()` sets `ProfileStatus.refreshing`, re-triggers profile watch / one-shot fetch as appropriate, then returns to `idle` (or `failure` with snackbar via existing listener).
- While `refreshing`, show `ProfileShimmer` in place of the signed-in content.
- Add `ProfileStatus.refreshing` to the existing enum (`idle`, `saving`, `failure`, `refreshing`).

## Shared AppImage

### Dependencies

- `cached_network_image` — network raster + disk cache
- `flutter_svg` — SVG for asset / network / file / string

### API (`lib/core/widgets/app_image.dart`)

Named constructors (preferred):

```dart
AppImage.network(String url, { … })
AppImage.asset(String path, { … })
AppImage.file(String path, { … })  // filesystem path; XFile.path callers OK
AppImage.memory(Uint8List bytes, { … })
```

Common params: `fit`, `width`, `height`, `placeholder`, `errorWidget`, `borderRadius`.

### Routing

- If path/URL ends with `.svg` (case-insensitive) or content is known SVG → `SvgPicture.asset` / `.network` / `.file` / `.memory` (or string).
- Else → `CachedNetworkImage` / `Image.asset` / `Image.file` / `Image.memory`.
- Empty or invalid source → `errorWidget` / placeholder; never throw from `build`.
- Clipping: honor `borderRadius`; avatars continue to use parent `ClipOval`.

### UserAvatar

- Replace direct `Image.asset` and `NetworkImage` with `AppImage` inside `ClipOval`.
- Keep initials fallback on error / missing URL.
- Leaderboard and avatar sheet pick up caching + SVG automatically.

## File map

| Path | Role |
|---|---|
| `lib/core/widgets/app_shimmer.dart` | Shared shimmer primitives |
| `lib/core/widgets/app_image.dart` | Shared media widget |
| `lib/core/widgets/user_avatar.dart` | Uses `AppImage` |
| `lib/features/profile/view/widgets/profile_shimmer.dart` | Profile skeleton |
| `lib/features/profile/view/profile_screen.dart` | Auth branch, Stack edit badge, RefreshIndicator |
| `lib/features/profile/cubit/profile_state.dart` | `ProfileStatus.refreshing` |
| `lib/features/profile/cubit/profile_cubit.dart` | `refresh()` |
| `pubspec.yaml` | Add `shimmer`, `cached_network_image`, `flutter_svg` |

## Error / edge cases

- Auth hung on `unknown`: shimmer remains until `signedOut` or `signedIn` (no timeout in v1).
- Image load failure: `errorWidget` or initials.
- Refresh failure: existing failure snackbar path; leave `refreshing`.
- Saving name/avatar (`ProfileStatus.saving`) does **not** swap the whole body to shimmer.

## Testing

- Widget: `AuthStatus.unknown` → `ProfileShimmer`, not signed-out mock.
- Widget: `AuthStatus.signedOut` → sign-in CTA still present.
- Widget/unit: `AppImage` selects SVG for `.svg` asset/network paths.
- Cubit: `refresh()` emits `refreshing` then `idle` (or failure) with profile preserved when possible.

## Package research summary

| Need | Chosen | Rejected (v1) |
|---|---|---|
| Shimmer | `shimmer` (high adoption, primitives) | `skeletonizer` (more magic), DIY via `flutter_animate` |
| Images | `cached_network_image` + `flutter_svg` | Low-adoption all-in-ones (`any_image_view`, etc.) |
