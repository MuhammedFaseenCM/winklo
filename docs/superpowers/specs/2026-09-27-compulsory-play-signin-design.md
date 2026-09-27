# Compulsory play sign-in + public leaderboard — design

Date: 2026-09-27  
Status: approved for implementation

## Goal

Require Google sign-in before entering any playable game. Guests may still browse Home and see the **live** Leaderboard tab, with a floating sign-in CTA. Profile signed-out behavior stays unchanged.

## Problem

Guest play removed the Home auth gate so anyone could open Zip / Path Words / Sudoku. Product now wants play behind sign-in again, while **opening** the leaderboard for guests (Firestore already allows public reads; the app UI still walls them off).

## Product decisions

| Topic | Choice |
|-------|--------|
| Home tile tap (Zip / Path Words / Sudoku) | Play-copy sign-in sheet; navigate only on success |
| “Not now” on play sheet | Stay on Home; no navigation |
| Deep link / direct game URL | GoRouter redirect to `/` (no game flash) |
| Other playable routes (`/word-match`, `/category-race`, etc.) | Same redirect gate when signed out |
| Browse Home signed-out | Allowed |
| Leaderboard tab signed-out | **Live rankings** (no blurred mock / full-screen wall) |
| Leaderboard signed-out CTA | Floating bottom button → existing Google sign-in sheet |
| Leaderboard signed-in | Unchanged (no floating button; “You” highlight works) |
| Profile signed-out | Unchanged |
| Post-game soft claim | Leave as-is (edge case if someone signs out mid-session) |
| Remote leaderboard **write** | Still requires Firebase auth |
| Firestore rules | No change for this feature (leaderboard read already public) |

**Supersedes (play + leaderboard tab):**

- [Guest play — sign-in only for leaderboard](2026-09-26-guest-play-leaderboard-signin-design.md) — play ungated; leaderboard tab behind sign-in
- Soft-claim design’s “Play gate | Unchanged — still no sign-in required to play” row only; celebration / soft-claim results UX otherwise remains

## Approach

**Home pre-gate + router redirect for play; open live leaderboard with floating sign-in.**

1. Shared `ensureSignedInForPlay(context)` → if signed out, `showSignInSheet` with play-focused copy; return success bool.
2. Home `openZip` / `openPathWords` / `openSudoku` call it before `push`.
3. GoRouter `redirect` blocks unsigned users from playable game paths → `/`, with auth as `refreshListenable`. Wait until auth status is known (`unknown` must not falsely redirect a signed-in user).
4. Leaderboard tab: remove signed-out empty/tease branch; always show live list; when `user == null`, overlay a floating bottom sign-in button.

## Architecture

```
Home tile (signed out)
  → ensureSignedInForPlay → showSignInSheet (play copy)
      → success → push /zip | /path-words | /sudoku
      → Not now → stay on Home

Home tile (signed in)
  → push game (no sheet)

Direct / deep link to game while signed out
  → GoRouter redirect → /

Leaderboard tab (signed out)
  → live WatchLeaderboard (currentUid null)
  → floating bottom Sign in CTA → showSignInSheet
  → on success → CTA hides; “You” highlight if applicable

Leaderboard tab (signed in)
  → live board unchanged; no floating CTA

Profile / soft-claim results
  → unchanged in this pass
```

### Playable paths (redirect when signed out)

At minimum: `/zip`, `/path-words`, `/sudoku`.  
Also gate other registered play routes that still exist: `/word-match`, `/word-match/:deckId`, `/category-race`.  
Do **not** redirect `/`, `/leaderboard`, `/profile`, `/results`.

### Auth cold start

While `AuthStatus.unknown`, do not treat the user as signed out for redirect purposes (avoid bouncing a restoring session off a game route). Once status is `signedOut` or `signedIn`, apply the gate.

## Copy (`AppStrings`)

| Key | Direction |
|-----|-----------|
| New play-gate title (e.g. `playSignInTitle`) | “Sign in to play” |
| New play-gate body (e.g. `playSignInBody`) | Short line: sign in with Google to play and save scores on today’s board |
| Floating leaderboard CTA label | Reuse `signInWithGoogle` |
| Sheet from floating CTA | Existing default sheet copy (`signInTitle` / `signInBody`) — update body so it no longer says guests can play without an account |
| Play-gate sheet | Only `playSignInTitle` / `playSignInBody` — never the ranking default |
| `signOutConfirmBody` | Mention that play requires sign-in again (leaderboard remains viewable signed out) |
| `leaderboardSignInHint` | Remove from Leaderboard tab; delete if unused elsewhere after this change |

## UI notes (floating CTA)

- Sticky / floating above the bottom nav safe area on the Leaderboard tab only when signed out.
- Does not block scrolling the list (list padding under the button).
- Primary action opens existing `showSignInSheet` (default or leaderboard-appropriate copy — not play-gate copy unless shared intentionally).
- Hide immediately when `AuthCubit` becomes signed in.

## Out of scope

- Anonymous Firebase auth
- Cleaning up soft-claim guest celebration path
- Changing Profile signed-out gate
- Backfilling historical local bests on Leaderboard-tab-only sign-in
- Firestore rule changes
- Auto-showing play sheet after deep-link bounce to Home

## Testing

- Home signed-out: tile → sheet; cancel → no navigation; success → navigates.
- Home signed-in: tile → game, no sheet.
- Router: unsigned location under a playable game path → lands on `/`.
- Auth `unknown` then `signedIn`: no erroneous redirect away from an in-progress restore if covered by tests/manual check.
- Leaderboard signed-out: live rows visible; floating CTA present; tap → sheet; success → CTA gone.
- Leaderboard signed-in: no floating CTA; “You” highlight still works.
- Existing soft-claim / profile tests left alone unless they assumed ungated Home play.

## Success criteria

1. Guests cannot start or deep-link into a playable game without signing in.
2. Guests can open Leaderboard and see live rankings with a floating sign-in button.
3. Signed-in play and leaderboard behavior match today aside from the new gates/CTA.
