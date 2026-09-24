# Dashboard with bottom navigation — design

Date: 2026-09-24  
Status: approved for implementation

## Goal

Add a **Dashboard shell** with a bottom navigation bar for **Home**, **Leaderboard**, and **Profile**. Home keeps the current games list. Profile becomes the home for auth and editable avatar/name. Games and results stay full-screen (no bottom nav).

## Product decisions

| Topic | Choice |
|-------|--------|
| Tabs | Home, Leaderboard, Profile |
| Home content | Existing games list (unchanged behavior) |
| Leaderboard | Existing full leaderboard screen as the tab body |
| Profile (signed out) | Sign-in CTA only; editing locked |
| Profile (signed in) | Avatar + name + Sign out; editable avatar and name |
| Avatar sources | Preset pack **and** gallery photo upload |
| Bottom nav on games/results | Hidden (full-screen sibling routes) |
| Navigation approach | `go_router` `StatefulShellRoute` + IndexedStack |
| Architecture | Feature-first BLoC / domain / data (existing patterns) |

## Approach

**StatefulShellRoute shell** (chosen over a local IndexedStack-only Dashboard and over nested Navigators per tab): preserves tab state, keeps deep links (`/leaderboard?game=…`), and matches the current `go_router` setup. Games/results remain sibling routes outside the shell so the bottom nav never appears there.

## Architecture

```
GoRouter
├── StatefulShellRoute (Dashboard shell + NavigationBar)
│   ├── /              → HomeScreen
│   ├── /leaderboard   → LeaderboardScreen
│   └── /profile       → ProfileScreen
└── sibling full-screen routes
    ├── /zip, /path-words, /word-match, …
    └── /results
```

```
AuthCubit (app-level session)
        │
ProfileCubit ← UpdateDisplayName / UpdateAvatar ← ProfileRepository
        │
ProfileRepositoryImpl → Firestore users/{uid} + Storage avatars/{uid}
                      → denormalize displayName/photoUrl on leaderboard docs
```

### Folder layout

| Layer | Location |
|-------|----------|
| Shell UI | `features/dashboard/view/` — shell scaffold + bottom nav |
| Home | `features/home/` — games list; remove header auth + leaderboard chrome |
| Leaderboard | `features/leaderboard/` — reuse screen/cubit |
| Profile | `features/profile/view/`, `features/profile/cubit/` |
| Auth | `features/auth/` — unchanged `AuthCubit` + `showSignInSheet` |
| Domain | `ProfileRepository`, `UpdateDisplayName`, `UpdateAvatar`; extend `AppUser` and `LeaderboardEntry` with optional `avatarId` |
| Data | `ProfileRepositoryImpl` (Firestore + Firebase Storage) |
| Router | `core/router/app_router.dart` |
| Copy | `AppStrings` only |
| DI | `core/di/app_repositories.dart` |

### State ownership

- **Auth session** — existing app-level `AuthCubit`
- **Profile editing** — feature-scoped `ProfileCubit` (freezed state: idle / saving / failure, draft name, avatar selection)
- **Leaderboard / Home** — existing cubits unchanged in responsibility
- **Domain** — no Flutter/UI imports

## UI & product behavior

### Bottom nav

- Destinations: Home, Leaderboard, Profile (icons + labels from `AppStrings`)
- Visible only on shell branches
- Tab switches keep each branch’s state (`StatefulShellRoute.indexedStack`)

### Home

- Same games list, streak, update banner/overlay, play gate as today
- Remove header **leaderboard** `IconButton` and **`_AuthAvatarButton`** (tabs replace both)

### Leaderboard tab

- Existing `LeaderboardScreen` (game + period controls)
- Post-game “See full leaderboard” navigates with `go('/leaderboard?game=…')` so the shell tab is selected (not a stacked push over Home)

### Profile — signed out

- Placeholder avatar, title/body copy, “Sign in with Google” → `showSignInSheet`
- No name/avatar editing until signed in

### Profile — signed in

- Large avatar (tap → avatar edit sheet)
- Display name (tap → edit field/dialog) with Save
- Sign out

### Avatar edit sheet

- Grid of bundled presets under `assets/avatars/` (placeholder art acceptable until final assets)
- “Choose from photos” via `image_picker` (gallery only; no camera in this scope)
- Preset select or successful upload applies immediately with loading/error feedback

### Display name rules

- Trim, non-empty, max 24 characters
- Validation shown in UI before save
- Persist to `users/{uid}` and denormalized leaderboard fields

## Data model

Extends existing Firestore profile docs:

```
users/{uid}:
  displayName: string
  photoUrl: string?       // custom upload URL or Google photo
  avatarId: string?       // e.g. "preset_01"; null when using photo
  updatedAt: timestamp
```

**Display priority**

1. If `avatarId` is set → bundled preset asset  
2. Else if `photoUrl` is non-empty → network image  
3. Else → first letter of `displayName`

**Custom photo**

- Upload to Firebase Storage at `avatars/{uid}.jpg` (overwrite)
- Store download URL as `photoUrl`, set `avatarId` to null

**Preset**

- Set `avatarId`, clear reliance on `photoUrl` for display (`avatarId` wins)

**Leaderboard denormalization**

- On successful name/avatar update, patch that user’s leaderboard entries with `displayName`, `photoUrl`, and `avatarId` so boards stay consistent (same spirit as submit-time denormalization today).
- **v1 display:** shared avatar helper (used by Profile + `LeaderboardRow`) resolves `avatarId` → asset, else `photoUrl` → network, else initials. Presets do not require Storage uploads.

## Packages & platform

- Add `image_picker`, `firebase_storage`
- Android/iOS gallery permissions as required by `image_picker`
- Document Storage rules + setup in `FIREBASE.md`

## Errors / fail-soft

- Firebase not ready → soft messaging consistent with auth/leaderboard today
- Upload or profile save failure → `ProfileCubit` failure + retry; do not leave inconsistent optimistic UI
- Sign-in cancel → remain on signed-out Profile
- Gallery permission denied → clear message, no crash

## Security

- `users/{uid}`: signed-in read; write only own uid (already aligned with leaderboard design)
- Storage `avatars/{uid}.*`: write/read only own uid
- No client writes to other users’ profiles

## Testing

- `ProfileCubit` `bloc_test` (signed-out CTA path, save name success/validation, preset select, upload failure)
- Usecase / repository unit tests with `mocktail`
- Router: shell has three branches; game/results routes have no bottom nav
- Home: no auth avatar / leaderboard header button
- Manual checklist in `FIREBASE.md`: Storage rules, profile write, avatar upload

## Out of scope

- Guest / local-only profiles
- Camera capture
- Avatar moderation, CDN transforms, multiple photo sizes
- Nested navigation stacks inside each tab
- Bottom nav on game or results screens
- Stats / streak section on Profile (auth + editable identity only)

## Migration / UX notes

- Existing Google `photoUrl` remains valid until the user picks a preset or uploads a custom photo
- Deep links and notification taps that target `/` or `/leaderboard` continue to work; add `/profile` if needed later
