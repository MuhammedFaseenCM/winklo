import {
  assertFails,
  assertSucceeds,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
  type Firestore,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { rulesEnv } from './helpers';

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await rulesEnv('demo-winklo-leagues');
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

const CODE = 'ABC234';

/** What the app writes when [owner] creates league [id]. */
function createBatch(store: Firestore, owner: string, id = 'L1', code = CODE) {
  const batch = writeBatch(store);
  batch.set(doc(store, `leagues/${id}`), {
    name: 'Family',
    ownerUid: owner,
    code,
    memberUids: [owner],
    createdAt: serverTimestamp(),
  });
  batch.set(doc(store, `league_codes/${code}`), { leagueId: id });
  return batch;
}

async function seedLeague(members: string[], owner = 'owner') {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const store = ctx.firestore() as unknown as Firestore;
    await setDoc(doc(store, 'leagues/L1'), {
      name: 'Family',
      ownerUid: owner,
      code: CODE,
      memberUids: members,
      createdAt: new Date(),
    });
    await setDoc(doc(store, `league_codes/${CODE}`), { leagueId: 'L1' });
  });
}

describe('creating a league', () => {
  it('works with the code doc in the same batch', async () => {
    await assertSucceeds(createBatch(db('owner'), 'owner').commit());
  });

  it('needs the code doc', async () => {
    const store = db('owner');
    await assertFails(
      setDoc(doc(store, 'leagues/L1'), {
        name: 'Family',
        ownerUid: 'owner',
        code: CODE,
        memberUids: ['owner'],
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('refuses another owner, extra members, bad names and codes', async () => {
    const cases: Array<Record<string, unknown>> = [
      { ownerUid: 'someone' },
      { memberUids: ['owner', 'friend'] },
      { memberUids: [] },
      { name: '' },
      { name: '   ' },
      { name: 'x'.repeat(31) },
      { extra: true },
    ];
    for (const override of cases) {
      const store = db('owner');
      const batch = writeBatch(store);
      batch.set(doc(store, 'leagues/L1'), {
        name: 'Family',
        ownerUid: 'owner',
        code: CODE,
        memberUids: ['owner'],
        createdAt: serverTimestamp(),
        ...override,
      });
      batch.set(doc(store, `league_codes/${CODE}`), { leagueId: 'L1' });
      await assertFails(batch.commit());
    }
    for (const code of ['ABC23', 'ABCI23', 'abc234']) {
      await assertFails(createBatch(db('owner'), 'owner', 'L1', code).commit());
    }
  });

  it('cannot take a code that is in use', async () => {
    await seedLeague(['owner']);
    await assertFails(createBatch(db('other'), 'other', 'L2').commit());
  });

  it('cannot point a code at an existing league', async () => {
    await seedLeague(['owner']);
    await assertFails(
      setDoc(doc(db('owner'), 'league_codes/XYZ234'), { leagueId: 'L1' }),
    );
  });

  it('needs to be signed in', async () => {
    await assertFails(createBatch(db(null), 'owner').commit());
  });
});

describe('reading leagues', () => {
  beforeEach(async () => {
    await seedLeague(['owner', 'member']);
  });

  it('anyone signed in can get a league or a code by id', async () => {
    await assertSucceeds(getDoc(doc(db('stranger'), 'leagues/L1')));
    await assertSucceeds(getDoc(doc(db('stranger'), `league_codes/${CODE}`)));
    await assertFails(getDoc(doc(db(null), 'leagues/L1')));
  });

  it('nobody can list all leagues or codes', async () => {
    await assertFails(getDocs(collection(db('member'), 'leagues')));
    await assertFails(getDocs(collection(db('member'), 'league_codes')));
  });

  it('members list their own leagues with array-contains', async () => {
    await assertSucceeds(
      getDocs(
        query(
          collection(db('member'), 'leagues'),
          where('memberUids', 'array-contains', 'member'),
        ),
      ),
    );
    await assertFails(
      getDocs(
        query(
          collection(db('stranger'), 'leagues'),
          where('memberUids', 'array-contains', 'member'),
        ),
      ),
    );
  });
});

describe('joining and leaving', () => {
  it('joining adds only your own uid', async () => {
    await seedLeague(['owner']);
    await assertSucceeds(
      updateDoc(doc(db('friend'), 'leagues/L1'), {
        memberUids: arrayUnion('friend'),
      }),
    );
  });

  it('you cannot add someone else, or change anything else', async () => {
    await seedLeague(['owner']);
    await assertFails(
      updateDoc(doc(db('friend'), 'leagues/L1'), {
        memberUids: arrayUnion('another'),
      }),
    );
    await assertFails(
      updateDoc(doc(db('friend'), 'leagues/L1'), {
        memberUids: arrayUnion('friend'),
        name: 'Mine',
      }),
    );
    await assertFails(
      updateDoc(doc(db('friend'), 'leagues/L1'), {
        memberUids: ['friend', 'owner'].reverse().concat(['x']),
      }),
    );
  });

  it('a league holds 30 at most', async () => {
    const members = ['owner', ...Array.from({ length: 29 }, (_, i) => `m${i}`)];
    await seedLeague(members);
    await assertFails(
      updateDoc(doc(db('late'), 'leagues/L1'), {
        memberUids: arrayUnion('late'),
      }),
    );
  });

  it('leaving removes only your own uid', async () => {
    await seedLeague(['owner', 'member', 'other']);
    await assertSucceeds(
      updateDoc(doc(db('member'), 'leagues/L1'), {
        memberUids: arrayRemove('member'),
      }),
    );
    await assertFails(
      updateDoc(doc(db('other'), 'leagues/L1'), {
        memberUids: arrayRemove('owner'),
      }),
    );
  });

  it('the owner cannot leave', async () => {
    await seedLeague(['owner', 'member']);
    await assertFails(
      updateDoc(doc(db('owner'), 'leagues/L1'), {
        memberUids: arrayRemove('owner'),
      }),
    );
  });
});

describe('the owner', () => {
  beforeEach(async () => {
    await seedLeague(['owner', 'member', 'other']);
  });

  it('removes other players', async () => {
    await assertSucceeds(
      updateDoc(doc(db('owner'), 'leagues/L1'), {
        memberUids: arrayRemove('member', 'other'),
      }),
    );
  });

  it('renames the league', async () => {
    await assertSucceeds(updateDoc(doc(db('owner'), 'leagues/L1'), { name: 'Cousins' }));
    await assertFails(updateDoc(doc(db('owner'), 'leagues/L1'), { name: '' }));
    await assertFails(updateDoc(doc(db('owner'), 'leagues/L1'), { ownerUid: 'member' }));
    await assertFails(updateDoc(doc(db('owner'), 'leagues/L1'), { code: 'XYZ234' }));
  });

  it('deletes the league and its code', async () => {
    const store = db('owner');
    const batch = writeBatch(store);
    batch.delete(doc(store, 'leagues/L1'));
    batch.delete(doc(store, `league_codes/${CODE}`));
    await assertSucceeds(batch.commit());
  });

  it('is the only one who can', async () => {
    await assertFails(
      updateDoc(doc(db('member'), 'leagues/L1'), {
        memberUids: arrayRemove('other'),
      }),
    );
    await assertFails(updateDoc(doc(db('member'), 'leagues/L1'), { name: 'Mine' }));
    await assertFails(deleteDoc(doc(db('member'), 'leagues/L1')));
    await assertFails(deleteDoc(doc(db('member'), `league_codes/${CODE}`)));
  });
});
