import { assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  where,
  type Firestore,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { rulesEnv } from './helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await rulesEnv('demo-winklo-levels');
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function db(uid: string | null, admin = false): Firestore {
  if (!uid) return env.unauthenticatedContext().firestore() as unknown as Firestore;
  return env.authenticatedContext(uid, admin ? { admin: true } : {}).firestore() as unknown as Firestore;
}

async function seed(path: string, data: Record<string, unknown>) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore() as unknown as Firestore, path), data);
  });
}

describe('level_worlds', () => {
  beforeEach(async () => {
    await seed('level_worlds/zip_1', { game: 'zip', order: 1, published: true, levels: [] });
    await seed('level_worlds/zip_2', { game: 'zip', order: 2, published: false, levels: [] });
  });

  it('anyone can read a published world', async () => {
    await assertSucceeds(getDoc(doc(db(null), 'level_worlds/zip_1')));
  });

  it('players cannot read an unpublished world; admins can', async () => {
    await assertFails(getDoc(doc(db('u1'), 'level_worlds/zip_2')));
    await assertSucceeds(getDoc(doc(db('a1', true), 'level_worlds/zip_2')));
  });

  it('players can list published worlds', async () => {
    const q = query(
      collection(db('u1'), 'level_worlds'),
      where('game', '==', 'zip'),
      where('published', '==', true),
      orderBy('order'),
    );
    await assertSucceeds(getDocs(q));
  });

  it('players cannot list without the published filter', async () => {
    await assertFails(getDocs(query(collection(db('u1'), 'level_worlds'), where('game', '==', 'zip'))));
  });

  it('nobody writes a world from a client', async () => {
    await assertFails(setDoc(doc(db('a1', true), 'level_worlds/zip_3'), { game: 'zip' }));
  });
});

describe('users/{uid}/level_progress', () => {
  const path = (uid: string, game = 'zip') => `users/${uid}/level_progress/${game}`;
  const valid = () => ({
    levels: { zip_1_01: { stars: 3, bestSeconds: 14 } },
    updatedAt: serverTimestamp(),
  });

  it('the owner writes and reads their progress', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), path('u1')), valid()));
    await assertSucceeds(getDoc(doc(db('u1'), path('u1'))));
  });

  it('nobody else reads or writes it', async () => {
    await seed(path('u1'), { levels: {}, updatedAt: new Date() });
    await assertFails(getDoc(doc(db('u2'), path('u1'))));
    await assertFails(setDoc(doc(db('u2'), path('u1')), valid()));
    await assertFails(getDoc(doc(db(null), path('u1'))));
  });

  it('refuses an unknown game, extra fields, a non-map and a client clock', async () => {
    await assertFails(setDoc(doc(db('u1'), path('u1', 'chess')), valid()));
    await assertFails(setDoc(doc(db('u1'), path('u1')), { ...valid(), extra: 1 }));
    await assertFails(setDoc(doc(db('u1'), path('u1')), { levels: [], updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db('u1'), path('u1')), { levels: {}, updatedAt: new Date(2020, 0, 1) }));
  });

  it('cannot be deleted', async () => {
    await seed(path('u1'), { levels: {}, updatedAt: new Date() });
    await assertFails(deleteDoc(doc(db('u1'), path('u1'))));
  });
});
