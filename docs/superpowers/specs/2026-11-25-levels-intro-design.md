# Levels intro and nudges: design

Date: 2026-11-25. Branch `feat/levels-intro`, from `master` at `4729ba4`. The design was approved in conversation.

## Why

Players aren't finding Levels. Home has no way in: it shows the three dailies and "More ways to play", and the only route is the Levels tab in the nav dock. Nothing in the app introduces a feature to players.

## What we're building (approved)

1. **"New: Levels" intro card.**
   - **When:** once per install, shown over Home the next time Home opens. Everyone sees it, including players who already play Levels.
   - **Content:** one row each for Zip and Path Words, each with a Play button. The button reads "Level 1", or the player's current level when they already have progress.
   - **Play:** goes to `/levels?open=<id>`. That opens the Levels tab on that game's map with the level's sheet open.
   - **Maybe later:** closes it for good.
   - **Not shown when:**
     - Home isn't the top route, because the app was opened from a notification or a deep link into a game;
     - a forced update is showing.

     In those cases it waits for the next normal Home visit.
2. **Guided first level.** The first level cleared on this phone shows a one-time tip on the level results: "Stars add up on your map. Play the next level now, or any time from the Levels tab."
3. **A "Levels" card on Home.** It always shows, below the three daily cards and above "More ways to play".
   - It shows total stars across Zip and Path Words.
   - It has a "Continue" button for the next level in the last game the player started a level in. With no level played yet, that's Path Words.
4. **A nudge after a daily clear.** Daily results get a row: "Done for today? Keep playing in Levels →", which goes to `/levels`. Level, archive and practice results don't show it.
5. **A dot on the Levels tab.** A small dot sits on the nav dock's Levels tab until the player opens that tab once.

## Calls Claude made

- All copy goes in `AppStrings`, in both en and ml.
- Analytics logs the intro shown, Play (with the game) and "Maybe later", so we can see whether it works.
- The flags live on the phone (SharedPreferences) behind a domain repository, `LevelsIntroRepository`. They aren't synced to the account.
- "Last game played" is saved when Play is tapped on a level sheet.

## Non-goals

- Any server or admin change.
- Push notifications.
- Changing the Levels screens themselves.

## Anti-goals

- Showing the intro over a game the player opened on purpose.
- Showing it more than once.
- A Home layout that pushes the daily cards below the fold on a 360×640 screen. The Levels card must be compact, the same height as "More ways to play".
