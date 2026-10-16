import { assertFails, assertSucceeds, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDocs,
  increment,
  serverTimestamp,
  setDoc,
  updateDoc,
  type Firestore,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { rulesEnv } from './helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await rulesEnv('demo-winklo-activity');
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

const DAY = '2026-10-17';
const INSTALL = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const userPath = (uid: string) => `daily_activity/${DAY}/users/${uid}`;

/** What 1.0.0+16 writes on a first open (activity_repository_impl.dart before this change). */
function oldCreate(uid: string) {
  return { uid, firstOpenAt: serverTimestamp(), lastOpenAt: serverTimestamp(), platform: 'android' };
}

/** What this build writes on a first open. */
function newCreate(uid: string) {
  return { ...oldCreate(uid), opens: 1, appVersion: '1.1.0', build: 19, installId: INSTALL };
}

/** What this build writes on a later open that day. */
function newUpdate() {
  return {
    lastOpenAt: serverTimestamp(),
    platform: 'android',
    opens: increment(1),
    appVersion: '1.1.0',
    build: 19,
    installId: INSTALL,
  };
}

describe('daily_activity users', () => {
  it('takes the old shape and the new one from the owner', async () => {
    await assertSucceeds(setDoc(doc(db('u1'), userPath('u1')), oldCreate('u1')));
    await assertSucceeds(setDoc(doc(db('u2'), userPath('u2')), newCreate('u2')));
  });

  it('refuses a create that is not the first open', async () => {
    await assertFails(setDoc(doc(db('u1'), userPath('u1')), { ...newCreate('u1'), opens: 2 }));
  });

  it.each([
    ['an uppercase install id', { installId: INSTALL.toUpperCase() }],
    ['a non-v4 install id', { installId: '3f2b8c1e-9a4d-1e7f-b123-0c9d8e7f6a5b' }],
    ['a 33-character version', { appVersion: '1'.repeat(33) }],
    ['an empty version', { appVersion: '' }],
    ['a string build', { build: '19' }],
    ['a negative build', { build: -1 }],
    ['an unknown key', { extra: true }],
  ])('refuses %s', async (_name, patch) => {
    await assertFails(setDoc(doc(db('u1'), userPath('u1')), { ...newCreate('u1'), ...patch }));
  });

  it('refuses writes to someone else’s doc', async () => {
    await assertFails(setDoc(doc(db('u2'), userPath('u1')), newCreate('u1')));
  });

  it('counts later opens up, never down', async () => {
    const store = db('u1');
    await setDoc(doc(store, userPath('u1')), newCreate('u1'));
    await assertSucceeds(updateDoc(doc(store, userPath('u1')), newUpdate()));
    await assertFails(updateDoc(doc(store, userPath('u1')), { lastOpenAt: serverTimestamp(), opens: 1 }));
  });

  it('still takes an old build’s update on a doc that has a count', async () => {
    const store = db('u1');
    await setDoc(doc(store, userPath('u1')), newCreate('u1'));
    await assertSucceeds(updateDoc(doc(store, userPath('u1')), { lastOpenAt: serverTimestamp(), platform: 'ios' }));
  });

  it('starts the count on a doc an old build created', async () => {
    const store = db('u1');
    await setDoc(doc(store, userPath('u1')), oldCreate('u1'));
    await assertSucceeds(updateDoc(doc(store, userPath('u1')), newUpdate()));
  });

  it('lets an admin list the day', async () => {
    await setDoc(doc(db('u1'), userPath('u1')), newCreate('u1'));
    await assertSucceeds(getDocs(collection(db('ops', true), `daily_activity/${DAY}/users`)));
    await assertFails(getDocs(collection(db('u2'), `daily_activity/${DAY}/users`)));
  });
});

describe('daily_activity guests', () => {
  const guestPath = `daily_activity/${DAY}/guests/${INSTALL}`;
  const guest = { installId: INSTALL, platform: 'android', appVersion: '1.1.0', build: 19, opens: 1 };

  it('only admins read them', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore() as unknown as Firestore, guestPath), guest);
    });
    await assertSucceeds(getDocs(collection(db('ops', true), `daily_activity/${DAY}/guests`)));
    await assertFails(getDocs(collection(db('u1'), `daily_activity/${DAY}/guests`)));
    await assertFails(getDocs(collection(db(null), `daily_activity/${DAY}/guests`)));
  });

  it('no client writes them, not even an admin', async () => {
    await assertFails(setDoc(doc(db(null), guestPath), guest));
    await assertFails(setDoc(doc(db('u1'), guestPath), guest));
    await assertFails(setDoc(doc(db('ops', true), guestPath), guest));
  });
});
