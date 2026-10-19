import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  type Firestore,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { rulesEnv, utcDayId } from './helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await rulesEnv('demo-winklo-leaderboard-skips');
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function db(uid: string | null, admin = false): Firestore {
  const ctx = uid
    ? env.authenticatedContext(uid, admin ? { admin: true } : {})
    : env.unauthenticatedContext();
  return ctx.firestore() as unknown as Firestore;
}

const today = utcDayId(0);

/** What FirestoreLeaderboardSkipLog writes for a refused clear. */
function skip(extra: Record<string, unknown> = {}) {
  return {
    uid: 'u1',
    gameId: 'zip',
    dayId: today,
    timeSeconds: 2,
    reason: 'too_fast',
    usedHints: false,
    hadMistakes: false,
    displayName: 'Ada',
    photoUrl: null,
    avatarId: 'preset_03',
    appVersion: '1.1.2',
    buildNumber: '21',
    platform: 'android',
    createdAt: serverTimestamp(),
    ...extra,
  };
}

const path = (uid = 'u1', game = 'zip', dayId = today) =>
  `leaderboard_skips/${uid}_${game}_${dayId}`;

describe('leaderboard skips', () => {
  it('take the owner’s refused clear', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), path()), skip()));
  });

  it('take one without an identity (profile unread)', async () => {
    const { displayName, photoUrl, avatarId, ...rest } = skip();
    void displayName;
    void photoUrl;
    void avatarId;
    await assertSucceeds(setDoc(doc(db('u1'), path()), rest));
  });

  it('take every final refusal reason', async () => {
    for (const reason of [
      'too_fast',
      'too_slow',
      'not_live',
      'permission_denied',
      'bad_request',
      'bad_proof',
      'unknown_puzzle',
    ]) {
      await assertSucceeds(setDoc(doc(db('u1'), path()), skip({ reason })));
    }
  });

  it('let a later refusal of the same day replace the first', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), path()), skip()));
    await assertSucceeds(
      setDoc(doc(db('u1'), path()), skip({ timeSeconds: 1, reason: 'too_fast' })),
    );
  });

  it('take a closed day from the past week, not older or far ahead', async () => {
    await assertSucceeds(
      setDoc(doc(db('u1'), path('u1', 'zip', utcDayId(-3))), skip({
        dayId: utcDayId(-3),
        reason: 'not_live',
      })),
    );
    for (const dayId of [utcDayId(-8), utcDayId(3), '2020-01-01']) {
      await assertFails(
        setDoc(doc(db('u1'), path('u1', 'zip', dayId)), skip({ dayId })),
      );
    }
  });

  it('only take the owner’s, under the id of its player, game and day', async () => {
    await assertFails(setDoc(doc(db('u2'), path()), skip()));
    await assertFails(setDoc(doc(db(null), path()), skip()));
    await assertFails(setDoc(doc(db('u1'), path('u1', 'sudoku')), skip()));
    await assertFails(setDoc(doc(db('u1'), 'leaderboard_skips/anything'), skip()));
  });

  it('refuse unknown keys, games and reasons, and bad values', async () => {
    const bad: Record<string, unknown>[] = [
      { extra: 1 },
      { reason: 'unauthorized' },
      { reason: 'whatever' },
      { timeSeconds: 0 },
      { timeSeconds: '6' },
      { usedHints: 'no' },
      { photoUrl: 'https://example.com/a.png' },
      { displayName: '' },
      { createdAt: new Date(0) },
      { appVersion: 'x'.repeat(33) },
    ];
    for (const extra of bad) {
      await assertFails(setDoc(doc(db('u1'), path()), skip(extra)));
    }
    await assertFails(
      setDoc(doc(db('u1'), path('u1', 'word_match')), skip({ gameId: 'word_match' })),
    );
  });

  it('are read by admins only, and never deleted', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), path()), skip()));
    await assertFails(getDoc(doc(db('u1'), path())));
    await assertSucceeds(getDoc(doc(db('admin', true), path())));
    await assertFails(deleteDoc(doc(db('u1'), path())));
    await assertFails(deleteDoc(doc(db('admin', true), path())));
  });
});
