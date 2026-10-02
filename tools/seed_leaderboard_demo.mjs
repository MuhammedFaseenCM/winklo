#!/usr/bin/env node
/**
 * Seed demo Zip / Path Words leaderboard entries for UI testing.
 *
 * Writes only to `leaderboards_debug` (the twin used by Flutter debug builds).
 * Never touches production `leaderboards`.
 *
 * Prefers the logged-in Firebase CLI access token (bypasses security rules via
 * Cloud IAM). Falls back to GOOGLE_APPLICATION_CREDENTIALS / play SA if set
 * and the CLI token is missing/expired.
 *
 * Usage (from repo root, with `firebase login` already done):
 *   node tools/seed_leaderboard_demo.mjs
 *
 * Optional:
 *   COUNT=30   number of fake players per board (default 28)
 *   CLEAR=1    delete demo_* docs under leaderboards_debug and exit (no re-seed)
 *
 * Doc IDs are demo_001 … demo_NNN so they never collide with real Auth uids.
 * Your Google account appears only after you clear a puzzle (submitBestTime).
 */

import { createRequire } from 'node:module';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, '..');
const require = createRequire(import.meta.url);

const count = Math.max(3, Number(process.env.COUNT || 28));
const games = ['zip', 'path_words'];

/** Debug twin only — never write demo_* into production `leaderboards`. */
const ROOT = 'leaderboards_debug';

const firstNames = [
  'Ava',
  'Noah',
  'Mia',
  'Liam',
  'Zoe',
  'Eli',
  'Nora',
  'Kai',
  'Iris',
  'Omar',
  'Ruby',
  'Finn',
  'Luna',
  'Jude',
  'Quinn',
  'Sage',
  'Remy',
  'Theo',
  'Nina',
  'Cole',
  'Vera',
  'Ash',
  'Ivy',
  'Rex',
  'Willa',
  'Jasper',
  'Clara',
  'Hugo',
  'Esme',
  'Leo',
];

function utcDayId(d = new Date()) {
  return d.toISOString().slice(0, 10);
}

function demoPlayers(n) {
  const players = [];
  for (let i = 1; i <= n; i++) {
    players.push({
      uid: `demo_${String(i).padStart(3, '0')}`,
      displayName: `${firstNames[(i - 1) % firstNames.length]} ${i}`,
      timeSeconds: 12 + (i - 1) * 3 + (i % 5),
      updatedAtMs: Date.UTC(2026, 8, 24, 4, 0, 0) + i * 1000,
    });
  }
  return players;
}

function readCliAccessToken() {
  const p = resolve(homedir(), '.config/configstore/firebase-tools.json');
  if (!existsSync(p)) return null;
  const j = JSON.parse(readFileSync(p, 'utf8'));
  const t = j.tokens;
  if (!t?.access_token) return null;
  if (typeof t.expires_at === 'number' && Date.now() > t.expires_at) {
    console.warn(
      'Firebase CLI access token expired. Run `firebase login` and retry.',
    );
    return null;
  }
  return t.access_token;
}

async function commitWrites(accessToken, projectId, writes) {
  async function commitChunk(chunk) {
    const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`;
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ writes: chunk }),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`commit failed ${res.status}: ${text.slice(0, 500)}`);
    }
  }

  for (let i = 0; i < writes.length; i += 400) {
    await commitChunk(writes.slice(i, i + 400));
    console.log(`committed ${Math.min(i + 400, writes.length)}/${writes.length}`);
  }
}

async function clearViaRest(accessToken, dayId) {
  const projectId = 'brain-zip-app';
  const base = `projects/${projectId}/databases/(default)/documents`;
  const deletes = [];

  for (const gameId of games) {
    for (let i = 1; i <= count; i++) {
      const uid = `demo_${String(i).padStart(3, '0')}`;
      deletes.push({
        delete: `${base}/${ROOT}/${gameId}/all_time/${uid}`,
      });
      deletes.push({
        delete: `${base}/${ROOT}/${gameId}/daily/${dayId}/entries/${uid}`,
      });
    }
  }

  console.log(`REST deletes: ${deletes.length}`);
  await commitWrites(accessToken, projectId, deletes);
}

async function seedViaRest(accessToken, players, dayId) {
  const projectId = 'brain-zip-app';
  const base = `projects/${projectId}/databases/(default)/documents`;
  const writes = [];

  for (const gameId of games) {
    for (let i = 0; i < players.length; i++) {
      const p = players[i];
      const timeSeconds =
        p.timeSeconds + (gameId === 'path_words' ? 5 : 0) + (i % 3);
      const fields = {
        timeSeconds: { integerValue: String(timeSeconds) },
        displayName: { stringValue: p.displayName },
        photoUrl: { nullValue: null },
        usedHints: { booleanValue: i % 3 !== 0 },
        hadMistakes: {
          booleanValue: gameId === 'sudoku' ? i % 4 !== 0 : false,
        },
        updatedAt: { timestampValue: new Date(p.updatedAtMs).toISOString() },
      };
      for (const path of [
        `${ROOT}/${gameId}/all_time/${p.uid}`,
        `${ROOT}/${gameId}/daily/${dayId}/entries/${p.uid}`,
      ]) {
        writes.push({ update: { name: `${base}/${path}`, fields } });
      }
    }
  }

  console.log(`REST writes: ${writes.length}`);
  await commitWrites(accessToken, projectId, writes);
}

async function seedViaAdmin(players, dayId, { clearOnly = false } = {}) {
  const admin = (await import('firebase-admin')).default;
  const credPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS ||
    resolve(root, 'play/play-service-account.json');
  const sa = require(credPath);
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      projectId: sa.project_id,
    });
  }
  const db = admin.firestore();

  async function clearDemoFromCollection(col) {
    const snap = await col.get();
    let batch = db.batch();
    let ops = 0;
    let n = 0;
    for (const doc of snap.docs) {
      if (!doc.id.startsWith('demo_')) continue;
      batch.delete(doc.ref);
      ops++;
      n++;
      if (ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return n;
  }

  async function writePlayers(col, list) {
    let batch = db.batch();
    let ops = 0;
    for (const p of list) {
      batch.set(
        col.doc(p.uid),
        {
          timeSeconds: p.timeSeconds,
          displayName: p.displayName,
          photoUrl: null,
          usedHints: p.usedHints ?? true,
          hadMistakes: p.hadMistakes ?? false,
          updatedAt: admin.firestore.Timestamp.fromMillis(p.updatedAtMs),
        },
        { merge: true },
      );
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  for (const gameId of games) {
    const allTime = db.collection(ROOT).doc(gameId).collection('all_time');
    const daily = db
      .collection(ROOT)
      .doc(gameId)
      .collection('daily')
      .doc(dayId)
      .collection('entries');
    if (clearOnly) {
      console.log(
        `[${gameId}] cleared demo: all_time=${await clearDemoFromCollection(allTime)} daily=${await clearDemoFromCollection(daily)}`,
      );
      continue;
    }
    const gamePlayers = players.map((p, i) => ({
      ...p,
      timeSeconds: p.timeSeconds + (gameId === 'path_words' ? 5 : 0) + (i % 3),
      usedHints: i % 3 !== 0,
      hadMistakes: gameId === 'sudoku' ? i % 4 !== 0 : false,
    }));
    await writePlayers(allTime, gamePlayers);
    await writePlayers(daily, gamePlayers);
    console.log(`[${gameId}] wrote ${gamePlayers.length} all_time + daily/${dayId}`);
  }
}

async function main() {
  const dayId = utcDayId();
  const players = demoPlayers(count);
  const clearOnly = process.env.CLEAR === '1';

  console.log(`Root: ${ROOT}`);
  console.log(`Day (UTC): ${dayId}`);
  if (clearOnly) {
    console.log(
      `CLEAR=1 — deleting demo_001…demo_${String(count).padStart(3, '0')} (no re-seed)`,
    );
  } else {
    console.log(
      `Players: ${players.length} (uids demo_001…demo_${String(count).padStart(3, '0')})`,
    );
  }

  const cliToken = readCliAccessToken();
  if (cliToken) {
    console.log('Auth: Firebase CLI access token');
    if (clearOnly) {
      await clearViaRest(cliToken, dayId);
    } else {
      await seedViaRest(cliToken, players, dayId);
    }
  } else {
    console.log('Auth: service account (Admin SDK)');
    await seedViaAdmin(players, dayId, { clearOnly });
  }

  if (clearOnly) {
    console.log(`Done — demo_* removed from ${ROOT}.`);
  } else {
    console.log(
      'Done. Open Leaderboard (Daily / All-time) for Zip and Path Words in a debug build.',
    );
    console.log(
      'Your real account joins after you clear a puzzle (or improve your time).',
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
