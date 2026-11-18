import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { dayIsLiveNow, nearWindowEdge, rulesEnv, utcDayId } from './helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await rulesEnv('demo-winklo-leaderboards');
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function db(uid: string | null): Firestore {
  return (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext())
    .firestore() as unknown as Firestore;
}

function entry(timeSeconds: number, extra: Record<string, unknown> = {}) {
  return {
    timeSeconds,
    updatedAt: serverTimestamp(),
    usedHints: false,
    hadMistakes: false,
    currentStreak: 2,
    displayName: 'Ada',
    ...extra,
  };
}

async function seed(path: string, data: Record<string, unknown>) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore() as unknown as Firestore, path), data);
  });
}

const today = utcDayId(0);
const daily = (game: string, dayId: string, uid = 'u1') =>
  `leaderboards/${game}/daily/${dayId}/entries/${uid}`;

describe('daily boards (phase 1)', () => {
  it('accept a time at the minimum on a live day', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), daily('zip', today)), entry(3)));
    await assertSucceeds(
      setDoc(doc(db('u1'), daily('sudoku', today)), entry(15)),
    );
  });

  // The minimum is 1 second for every game (`minLeaderboardSeconds`).
  it('refuse a time under the game minimum', async () => {
    for (const game of ['zip', 'sudoku', 'path_words']) {
      await assertFails(setDoc(doc(db('u1'), daily(game, today)), entry(0)));
    }
  });

  it('refuse a day id that is not yyyy-MM-dd or not a real day', async () => {
    for (const dayId of ['20261015', '2026-1-05', '2026-02-30', 'today']) {
      await assertFails(setDoc(doc(db('u1'), daily('zip', dayId)), entry(30)));
    }
  });

  it('refuse a day that is not live', async () => {
    for (const dayId of [utcDayId(2), utcDayId(-2), '2020-01-01']) {
      await assertFails(setDoc(doc(db('u1'), daily('zip', dayId)), entry(30)));
    }
  });

  it('follow the live window for yesterday and tomorrow', async () => {
    for (const dayId of [utcDayId(-1), utcDayId(1)]) {
      if (nearWindowEdge(dayId)) continue;
      const write = setDoc(doc(db('u1'), daily('zip', dayId)), entry(30));
      if (dayIsLiveNow(dayId)) {
        await assertSucceeds(write);
      } else {
        await assertFails(write);
      }
    }
  });

  it('refuse a non-positive time, allow a one-second clear', async () => {
    await seed(daily('zip', today), { ...entry(40), updatedAt: new Date() });
    await assertFails(
      setDoc(doc(db('u1'), daily('zip', today)), entry(0), { merge: true }),
    );
    await assertSucceeds(
      setDoc(doc(db('u1'), daily('zip', today)), entry(1), { merge: true }),
    );
  });

  it('still refresh the name on an existing entry', async () => {
    await seed(daily('zip', today), { ...entry(1), updatedAt: new Date() });
    await assertSucceeds(
      updateDoc(doc(db('u1'), daily('zip', today)), {
        displayName: 'Ada L',
        currentStreak: 3,
      }),
    );
  });

  it('only take writes from the owner', async () => {
    await assertFails(setDoc(doc(db('u2'), daily('zip', today)), entry(30)));
    await assertFails(setDoc(doc(db(null), daily('zip', today)), entry(30)));
  });
});

describe('all-time boards (phase 1)', () => {
  const allTime = (game: string, uid = 'u1') =>
    `leaderboards/${game}/all_time/${uid}`;

  it('need a positive time of at least one second', async () => {
    await assertFails(setDoc(doc(db('u1'), allTime('zip')), entry(0)));
    await assertSucceeds(setDoc(doc(db('u1'), allTime('zip')), entry(1)));
  });
});

describe('debug boards', () => {
  it('keep their old checks (no minimum, any day id)', async () => {
    await assertSucceeds(
      setDoc(
        doc(db('u1'), 'leaderboards_debug/zip/daily/202610151201/entries/u1'),
        entry(3),
      ),
    );
    await assertSucceeds(
      setDoc(doc(db('u1'), 'leaderboards_debug/zip/all_time/u1'), entry(3)),
    );
  });
});

describe('weekly boards', () => {
  const weekly = 'leaderboards/zip/weekly/2026-W42/entries/u1';

  it('are public to read', async () => {
    await seed(weekly, { daysCleared: 2, totalSeconds: 90 });
    await assertSucceeds(getDoc(doc(db(null), weekly)));
  });

  it('take no client writes, not even from the owner', async () => {
    await assertFails(
      setDoc(doc(db('u1'), weekly), {
        days: { [today]: 30 },
        daysCleared: 1,
        totalSeconds: 30,
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

describe('levels boards', () => {
  const levels = 'leaderboards/zip/levels/u1';
  const records = 'leaderboards/zip/level_records/u1';
  const row = {
    stars: 12,
    levelsCleared: 5,
    timeSeconds: 300,
    displayName: 'Ada',
    updatedAt: serverTimestamp(),
  };

  it('rows are readable by any signed-in player', async () => {
    await seed(levels, { ...row, updatedAt: new Date() });
    await assertSucceeds(getDoc(doc(db('u2'), levels)));
  });

  it('owner cannot create or update score fields', async () => {
    await assertFails(setDoc(doc(db('u1'), levels), row));
    await seed(levels, { ...row, updatedAt: new Date() });
    for (const field of ['stars', 'levelsCleared', 'timeSeconds']) {
      await assertFails(
        updateDoc(doc(db('u1'), levels), { [field]: 1, updatedAt: serverTimestamp() }),
      );
    }
    await assertFails(setDoc(doc(db('u2'), levels), row));
  });

  it('owner can refresh name, photo and avatar on an existing row', async () => {
    await seed(levels, { ...row, updatedAt: new Date() });
    await assertSucceeds(
      updateDoc(doc(db('u1'), levels), { displayName: 'Grace', avatarId: 'a1' }),
    );
    await assertFails(updateDoc(doc(db('u2'), levels), { displayName: 'Grace' }));
  });

  it('owner cannot add a currentStreak to a row', async () => {
    await seed(levels, { ...row, updatedAt: new Date() });
    await assertFails(updateDoc(doc(db('u1'), levels), { currentStreak: 3 }));
  });

  it('rows cannot be deleted', async () => {
    await seed(levels, { ...row, updatedAt: new Date() });
    await assertFails(deleteDoc(doc(db('u1'), levels)));
  });

  it('rejects a game outside the valid ones', async () => {
    const path = 'leaderboards/bogus/levels/u1';
    await seed(path, { ...row, updatedAt: new Date() });
    await assertFails(getDoc(doc(db('u1'), path)));
    await assertFails(updateDoc(doc(db('u1'), path), { displayName: 'Grace' }));
    await seed('leaderboards/bogus/level_records/u1', { levels: {} });
    await assertFails(getDoc(doc(db('u1'), 'leaderboards/bogus/level_records/u1')));
  });

  it('records are readable by their owner only', async () => {
    await seed(records, { levels: { l1: { stars: 3 } }, updatedAt: new Date() });
    await assertSucceeds(getDoc(doc(db('u1'), records)));
    await assertFails(getDoc(doc(db('u2'), records)));
    await assertFails(getDoc(doc(db(null), records)));
  });

  it('records take no client writes, not even from the owner', async () => {
    await assertFails(setDoc(doc(db('u1'), records), { levels: {} }));
    await seed(records, { levels: {}, updatedAt: new Date() });
    await assertFails(updateDoc(doc(db('u1'), records), { levels: { l1: 1 } }));
    await assertFails(deleteDoc(doc(db('u1'), records)));
  });
});

describe('daily puzzles', () => {
  const compact = (offset: number) => utcDayId(offset).replace(/-/g, '');

  beforeEach(async () => {
    for (const offset of [-3, 0, 1, 2]) {
      await seed(`zip_levels/daily_${compact(offset)}`, { size: 5 });
    }
    await seed('zip_levels/level_01', { size: 5 });
    await seed(`sudoku_levels/sudoku_${compact(2)}`, { size: 6 });
  });

  it('can be read once live, and old ones stay readable', async () => {
    await assertSucceeds(getDoc(doc(db(null), `zip_levels/daily_${compact(0)}`)));
    await assertSucceeds(getDoc(doc(db('u1'), `zip_levels/daily_${compact(-3)}`)));
  });

  it('cannot be read before they go live', async () => {
    await assertFails(getDoc(doc(db(null), `zip_levels/daily_${compact(2)}`)));
    await assertFails(getDoc(doc(db('u1'), `zip_levels/daily_${compact(2)}`)));
  });

  it("open tomorrow's at 10:00 UTC today", async () => {
    const tomorrow = Date.parse(`${utcDayId(1)}T00:00:00Z`);
    const opens = tomorrow - 14 * 60 * 60 * 1000;
    if (Math.abs(Date.now() - opens) < 60_000) return;
    const read = getDoc(doc(db('u1'), `zip_levels/daily_${compact(1)}`));
    if (Date.now() >= opens) {
      await assertSucceeds(read);
    } else {
      await assertFails(read);
    }
  });

  it('are readable by admins at any time', async () => {
    const admin = env
      .authenticatedContext('admin1', { admin: true })
      .firestore() as unknown as Firestore;
    await assertSucceeds(getDoc(doc(admin, `zip_levels/daily_${compact(2)}`)));
  });

  it('leave other ids alone', async () => {
    await assertSucceeds(getDoc(doc(db(null), 'zip_levels/level_01')));
    await assertSucceeds(getDoc(doc(db(null), `sudoku_levels/sudoku_${compact(2)}`)));
  });

  it('cannot be listed except by admins', async () => {
    const { collection, getDocs } = await import('firebase/firestore');
    await assertFails(getDocs(collection(db('u1'), 'zip_levels')));
    const admin = env
      .authenticatedContext('admin1', { admin: true })
      .firestore() as unknown as Firestore;
    await assertSucceeds(getDocs(collection(admin, 'zip_levels')));
  });

  it('take no client writes', async () => {
    await assertFails(setDoc(doc(db('u1'), 'zip_levels/x'), { size: 5 }));
  });
});

describe('phase 2 (directLeaderboardWritesAllowed() returns false)', () => {
  let phase2: RulesTestEnvironment;

  beforeAll(async () => {
    const rulesPath = fileURLToPath(new URL('../firestore.rules', import.meta.url));
    const rules = readFileSync(rulesPath, 'utf8');
    const flipped = rules.replace(
      /function directLeaderboardWritesAllowed\(\) \{\s*return true;\s*\}/,
      'function directLeaderboardWritesAllowed() { return false; }',
    );
    expect(flipped).not.toBe(rules);
    const host = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
    const [hostname, port] = host.split(':');
    phase2 = await initializeTestEnvironment({
      projectId: 'demo-winklo-phase2',
      firestore: { rules: flipped, host: hostname, port: Number(port) },
    });
  });

  afterAll(async () => {
    await phase2.cleanup();
  });

  const user = () => phase2.authenticatedContext('u1').firestore() as unknown as Firestore;

  it('refuses direct time writes', async () => {
    await assertFails(setDoc(doc(user(), daily('zip', today)), entry(30)));
    await assertFails(setDoc(doc(user(), 'leaderboards/zip/all_time/u1'), entry(30)));
  });

  it('keeps identity refreshes but not streak changes', async () => {
    await phase2.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore() as unknown as Firestore, daily('zip', today)), {
        ...entry(40),
        updatedAt: new Date(),
      });
    });
    await assertSucceeds(
      updateDoc(doc(user(), daily('zip', today)), { displayName: 'Ada L' }),
    );
    await assertFails(
      updateDoc(doc(user(), daily('zip', today)), { currentStreak: 99 }),
    );
  });

  it('keeps debug builds writing directly', async () => {
    await assertSucceeds(
      setDoc(doc(user(), 'leaderboards_debug/zip/all_time/u1'), entry(3)),
    );
  });
});
