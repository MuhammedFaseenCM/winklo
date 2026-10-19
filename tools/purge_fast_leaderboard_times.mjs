#!/usr/bin/env node
/**
 * Fair play, phase 1: removes leaderboard entries faster than the game's
 * minimum time from the release boards.
 *
 * The boards are improve-only, so an entry written before the minimum existed
 * (say 3 s) would sit above every honest time for good: nothing at or above
 * the minimum can beat it. Run this once after deploying the phase-1 rules.
 * It reads `leaderboards/{game}/all_time` and the daily boards of the days
 * still live (yesterday, today and tomorrow in UTC), and deletes entries
 * whose `timeSeconds` is under the minimum. A player's next honest clear puts
 * them back.
 *
 * Dry run by default; APPLY=1 deletes. Uses the Firebase CLI's login token,
 * like seed_leaderboard_demo.mjs (`firebase login` first).
 *
 *   node tools/purge_fast_leaderboard_times.mjs
 *   APPLY=1 node tools/purge_fast_leaderboard_times.mjs
 */

import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { resolve } from 'node:path';

const projectId = process.env.PROJECT_ID || 'brain-zip-app';
const apply = process.env.APPLY === '1';

/** MIN_SECONDS in workers/leaderboard/src/limits.ts (pinned by test/firestore). */
const MIN_SECONDS = { zip: 3, path_words: 15, sudoku: 15 };

const base = `projects/${projectId}/databases/(default)/documents`;
const api = 'https://firestore.googleapis.com/v1';

function cliAccessToken() {
  const p = resolve(homedir(), '.config/configstore/firebase-tools.json');
  if (!existsSync(p)) return null;
  const t = JSON.parse(readFileSync(p, 'utf8')).tokens;
  if (!t?.access_token) return null;
  if (typeof t.expires_at === 'number' && Date.now() > t.expires_at) return null;
  return t.access_token;
}

function utcDayId(offsetDays) {
  return new Date(Date.now() + offsetDays * 86_400_000).toISOString().slice(0, 10);
}

/** Names of the docs in [parent]/[collectionId] with timeSeconds < [min]. */
async function fastEntries(token, parent, collectionId, min) {
  const res = await fetch(`${api}/${parent}:runQuery`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: {
          fieldFilter: {
            field: { fieldPath: 'timeSeconds' },
            op: 'LESS_THAN',
            value: { integerValue: String(min) },
          },
        },
      },
    }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`query failed ${res.status}: ${text.slice(0, 300)}`);
  return JSON.parse(text)
    .map((row) => row.document)
    .filter(Boolean)
    .map((doc) => ({ name: doc.name, time: doc.fields?.timeSeconds?.integerValue }));
}

async function main() {
  const token = cliAccessToken();
  if (!token) {
    console.error('No Firebase CLI token. Run `firebase login` and retry.');
    process.exit(1);
  }
  const found = [];
  for (const [game, min] of Object.entries(MIN_SECONDS)) {
    const gameDoc = `${base}/leaderboards/${game}`;
    found.push(...(await fastEntries(token, gameDoc, 'all_time', min)));
    for (const day of [utcDayId(-1), utcDayId(0), utcDayId(1)]) {
      found.push(
        ...(await fastEntries(token, `${gameDoc}/daily/${day}`, 'entries', min)),
      );
    }
  }
  for (const entry of found) {
    console.log(`${entry.time}s  ${entry.name.slice(base.length + 1)}`);
  }
  console.log(`${found.length} entries under the minimum.`);
  if (!apply || found.length === 0) {
    if (found.length) console.log('Dry run: set APPLY=1 to delete them.');
    return;
  }
  for (let i = 0; i < found.length; i += 400) {
    const chunk = found.slice(i, i + 400);
    const res = await fetch(`${api}/${base}:commit`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ writes: chunk.map((e) => ({ delete: e.name })) }),
    });
    if (!res.ok) throw new Error(`delete failed ${res.status}: ${await res.text()}`);
  }
  console.log(`Deleted ${found.length}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
