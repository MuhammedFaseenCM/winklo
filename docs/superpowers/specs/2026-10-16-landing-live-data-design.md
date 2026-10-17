# Landing page with live data

**Date:** 2026-10-16 · **Branch:** `feat/landing-live-data` (from `feat/roadmap-batch`)

## Goal

`winklo.pages.dev` is a static page: nothing on it changes from day to day. Make it show what's actually happening in Winklo today, and bring its copy up to date with 1.1.0.

## What the page shows

- **Today's boards** (new section under the hero): one card per game with today's real board drawn from its puzzle document, the difficulty, the fastest three clears today and how many players have cleared it. Zip shows its numbers and walls, Sudoku its givens, Path Words its letter grid and the number of hidden words. Nothing that solves the puzzle reaches the browser: the solution, Zip's path and Path Words' words and routes are never fetched.
- **A live line in the hero:** today's clears across the three games and the time until the next set ("New boards in 21h 04m", counted to the visitor's local midnight).
- **Today's set in the hero** on wide screens: the three boards as a fanned stack, linking to the section.
- **Refreshed copy:** leagues, archive and practice, badges and stats, the home-screen widget, reminders and Malayalam, as built on `feat/roadmap-batch`. This branch is meant to merge with or after it.
- **Structured data:** a `MobileApplication` JSON-LD block for search engines.
- **Type and layout** (from review): headings use Lexend, the app's font, instead of Syne, whose extended letterforms read as stretched; labels are sentence case without wide letter-spacing. On screens 62rem and wider every section shares one 72rem grid (steps, features and games in three columns, the video beside its text) instead of a phone-width column in the middle of the page. Two older bugs are fixed on the way: the Daily habit section had no side padding, and the screenshot rail's figures kept the browser's 40px margins and snapped flush to the screen edge.

The day is the visitor's local date, as in the app (`daily_YYYYMMDD` for the phone's local date).

## Where the data comes from

A Cloudflare Pages Function at `GET /api/today?day=YYYY-MM-DD`, deployed with the site from `workers/site/` (`wrangler pages deploy ../../docs`). It reads Firestore's REST API without credentials, so it can only read what the rules already make public: the `daily_YYYYMMDD` puzzle documents once their day is live, and the leaderboards.

Why not read Firestore from the browser: every visit would cost about 18 reads from the Spark plan's 50,000 a day, which the app shares. A burst of visits could use up the app's quota. The function answers from Cloudflare's cache instead.

- **Reads per cache miss:** each game costs 1 read for the puzzle document (cached 6 hours, since it doesn't change), up to 3 for the top entries and 1 for the count.
- **Cache:** the answer is kept in Cloudflare's Cache API for 5 minutes per day (30 seconds when a read failed) and in the browser for 1 minute. Only days that are live somewhere are accepted (the leaderboard rule's window, 14 hours before to 36 hours after UTC midnight, from `workers/leaderboard/src/days.ts`), and other query parameters are left out of the cache key, so at most three keys exist at a time. Worst case, with a request in every 5-minute window all day, that is about 3,500 reads (12 per miss) per day key per Cloudflare location. Real traffic is far below that. Answers carry `x-winklo-cache: hit|miss` to check this in production.
- **Fair play:** entries under each game's minimum time (Zip 10 s, Path Words and Sudoku 15 s, imported from `workers/leaderboard/src/limits.ts`) are left out of the top three and the count, because older builds wrote such times directly before the minimums existed. On 15 October that left 3 of 9 Zip entries.
- **Deploy:** the Deploy site workflow runs `wrangler pages deploy ../../docs` from `workers/site/`, which picks up `functions/`. No `wrangler.toml`, so the Pages project's dashboard settings stay in charge; `npm run dev` passes a compatibility date for local runs.

## Privacy

Leaderboard names are shortened before they leave the function: "Arun Kumar" becomes "Arun K.". Photos, avatars and uids aren't sent. The privacy policy said names show "in the app"; it now also says the website shows the shortened name and time of today's fastest three.

## Failure handling

The live section, the hero's live line and the hero's board stack start hidden and appear once `/api/today` answers. If the function fails or the page is opened without it (GitHub Pages, a plain static server), they stay hidden and the page reads as before. Each game is independent: a missing puzzle document shows "Today's board is waiting in the app." for that board only, a failed leaderboard read hides its list, and an empty leaderboard says "No clears yet today. Be the first." The function answers 502 only when nothing at all could be read. An open page refreshes after 5 minutes when visible, and at the visitor's midnight.

## Testing

- `workers/site`: vitest tests for the pure parts (day window, Firestore value decoding, board shaping that drops the solution, name shortening, the handler with a fake `fetch` and cache) and `tsc`. CI runs them with the other Workers.
- The page itself: checked in a browser against `wrangler pages dev` at 360 px and 1280 px, with the function reading production Firestore (today's empty boards and 15 October's full ones). At 360 px nothing scrolls sideways but the two rails; on desktop every section starts at the same left edge.

## Out of scope

- Playing a puzzle on the web.
- All-time records: the stored all-time Zip times start at 3 seconds, from before the minimums, until `tools/purge_fast_leaderboard_times.mjs` runs.
- Store rating or install counts: Play has no public API for them.
