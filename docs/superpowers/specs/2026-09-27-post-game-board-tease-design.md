# Post-game board tease — design

Date: 2026-09-27  
Status: approved for implementation

## Goal

Fill the guest Zip / Path Words results mid-gap with a **compact blurred mini-board tease** (social proof) — visible without sign-in — that taps into the same soft-claim flow as Save to board.

## Product decisions

| Topic | Choice |
|-------|--------|
| Audience | Guests only on Zip / Path Words results |
| Content | Compact blurred mock board (reuse `LeaderboardSignedOutMock`, top ~3 rows) |
| Interaction | Tap tease → same claim sheet / submit as Save CTA |
| Live board without auth | Out of scope |
| Signed-in | Unchanged (real mini board) |
| Height | Capped ~160–200 logical px; clipped |

Builds on celebrate + soft claim + celebration polish specs.

## Approach

Between celebration card and tomorrow / Save CTAs, insert a rounded card:

1. Clipped `LeaderboardSignedOutMock` (top rows only)  
2. Light blur + scrim (same idea as `BlurredMockEmptyBody`, compact)  
3. Short overlay line: join / save your time to today’s board  
4. `InkWell` / tap → `_signInAndSync`

## Copy

New `AppStrings` e.g. `resultsBoardTeaseHint` — board is live; save your time to join.  
Reuse claim sheet title/body.

## Out of scope

- Public Firestore reads without auth  
- Ghost “You” rank calculation  
- Cross-play / other-game CTA  

## Testing

- Guest results show board tease; tap opens claim sheet  
- Signed-in: no tease; mini board present  
- Back home / Save still work  
