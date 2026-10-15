import { LEADERBOARD_GAMES, userDocPath } from './paths';

const FIRESTORE_API = 'https://firestore.googleapis.com/v1';

const USER_SUBCOLLECTIONS = [
  'game_days',
  'game_days_debug',
  'game_streaks',
  'game_streaks_debug',
] as const;

const LEADERBOARD_ROOTS = ['leaderboards', 'leaderboards_debug'] as const;

/** Only the leaderboard Worker writes weekly entries, and only on the release root. */
const WEEKLY_ROOTS = ['leaderboards'] as const;

/** Top-level collections whose docs name their owner in a `uid` field. */
export const UID_FIELD_COLLECTIONS = ['issue_reports', 'client_errors'] as const;

const LIST_PAGE_SIZE = 300;
const QUERY_PAGE_SIZE = 300;

/**
 * Deletes per `batchWrite` call. Each call is one Worker subrequest (the Free
 * plan allows 50 per request), so the wipe makes a few dozen calls at most.
 */
export const DELETE_BATCH_SIZE = 100;

/** Firebase uids are short alphanumeric strings; anything else is refused. */
const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export type WipeResult =
  | { ok: true; deleted: number }
  | { ok: false; errorMessage: string };

export type LeaderboardRoot = (typeof LEADERBOARD_ROOTS)[number];

function documentsBase(projectId: string): string {
  return `projects/${projectId}/databases/(default)/documents`;
}

export function allTimeLeaderboardPath(
  projectId: string,
  root: LeaderboardRoot,
  game: string,
  uid: string,
): string {
  return `${documentsBase(projectId)}/${root}/${game}/all_time/${uid}`;
}

export function dailyEntryPath(
  projectId: string,
  root: LeaderboardRoot,
  game: string,
  dayId: string,
  uid: string,
): string {
  return `${documentsBase(projectId)}/${root}/${game}/daily/${dayId}/entries/${uid}`;
}

export function weeklyEntryPath(
  projectId: string,
  root: LeaderboardRoot,
  game: string,
  weekId: string,
  uid: string,
): string {
  return `${documentsBase(projectId)}/${root}/${game}/weekly/${weekId}/entries/${uid}`;
}

export function leagueCodePath(projectId: string, code: string): string {
  return `${documentsBase(projectId)}/league_codes/${code}`;
}

export function dailyActivityUserPath(
  projectId: string,
  dayId: string,
  uid: string,
): string {
  return `${documentsBase(projectId)}/daily_activity/${dayId}/users/${uid}`;
}

/**
 * Names of every doc in [collectionPath].
 *
 * With [showMissing], also the "missing" docs that exist only as parents of a
 * subcollection. The app writes `leaderboards/{game}/daily/{dayId}/entries/{uid}`
 * and `daily_activity/{dayId}/users/{uid}` without ever creating the day docs,
 * so a plain list of those day collections returns nothing.
 */
export async function listDocumentNames(
  accessToken: string,
  collectionPath: string,
  options: { showMissing?: boolean } = {},
): Promise<string[]> {
  const names: string[] = [];
  let pageToken: string | undefined;
  do {
    const qs = new URLSearchParams({ pageSize: String(LIST_PAGE_SIZE) });
    if (options.showMissing) qs.set('showMissing', 'true');
    if (pageToken) qs.set('pageToken', pageToken);
    const res = await fetch(`${FIRESTORE_API}/${collectionPath}?${qs}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (res.status === 404) return names;
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`firestore_list_failed:${res.status}:${text.slice(0, 300)}`);
    }
    const json = JSON.parse(text) as {
      documents?: Array<{ name: string }>;
      nextPageToken?: string;
    };
    for (const doc of json.documents ?? []) {
      if (doc.name) names.push(doc.name);
    }
    pageToken = json.nextPageToken;
  } while (pageToken);
  return names;
}

function docIdFromResourceName(name: string): string {
  return name.split('/').pop() ?? name;
}

export function uidStructuredQuery(
  collectionId: string,
  uid: string,
  startAfterDocName?: string,
): Record<string, unknown> {
  return fieldStructuredQuery(collectionId, 'uid', 'EQUAL', uid, startAfterDocName);
}

/** Docs of top-level [collectionId] whose [fieldPath] matches [uid] by [op], by name. */
export function fieldStructuredQuery(
  collectionId: string,
  fieldPath: string,
  op: 'EQUAL' | 'ARRAY_CONTAINS',
  uid: string,
  startAfterDocName?: string,
): Record<string, unknown> {
  const structuredQuery: Record<string, unknown> = {
    from: [{ collectionId }],
    where: {
      fieldFilter: {
        field: { fieldPath },
        op,
        value: { stringValue: uid },
      },
    },
    orderBy: [{ field: { fieldPath: '__name__' }, direction: 'ASCENDING' }],
    limit: QUERY_PAGE_SIZE,
  };
  if (startAfterDocName) {
    structuredQuery.startAt = {
      values: [{ referenceValue: startAfterDocName }],
      before: false,
    };
  }
  return structuredQuery;
}

type QueriedDoc = { name: string; fields: Record<string, unknown> };

/** Every doc a paged [query] returns. */
async function queryDocs(
  accessToken: string,
  projectId: string,
  query: (startAfterDocName?: string) => Record<string, unknown>,
): Promise<QueriedDoc[]> {
  const url = `${FIRESTORE_API}/${documentsBase(projectId)}:runQuery`;
  const docs: QueriedDoc[] = [];
  let startAfterDocName: string | undefined;
  for (;;) {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ structuredQuery: query(startAfterDocName) }),
    });
    const text = await res.text();
    if (!res.ok) {
      throw new Error(`firestore_query_failed:${res.status}:${text.slice(0, 300)}`);
    }
    const rows = JSON.parse(text) as Array<{
      document?: { name: string; fields?: Record<string, unknown> };
    }>;
    let matched = 0;
    for (const row of rows) {
      const name = row.document?.name;
      if (!name) continue;
      docs.push({ name, fields: row.document?.fields ?? {} });
      startAfterDocName = name;
      matched += 1;
    }
    if (matched < QUERY_PAGE_SIZE) return docs;
  }
}

/** Names of the docs in top-level [collectionId] whose `uid` is [uid]. */
async function queryNamesByUid(
  accessToken: string,
  projectId: string,
  collectionId: string,
  uid: string,
): Promise<string[]> {
  const docs = await queryDocs(accessToken, projectId, (after) =>
    uidStructuredQuery(collectionId, uid, after),
  );
  return docs.map((doc) => doc.name);
}

function stringField(fields: Record<string, unknown>, key: string): string | null {
  const value = fields[key] as { stringValue?: unknown } | undefined;
  return typeof value?.stringValue === 'string' ? value.stringValue : null;
}

/** A batchWrite write: a delete, or taking [uid] out of a league's members. */
export type WipeWrite =
  | { delete: string }
  | {
      update: { name: string };
      updateMask: { fieldPaths: string[] };
      updateTransforms: Array<{
        fieldPath: string;
        removeAllFromArray: { values: Array<{ stringValue: string }> };
      }>;
      currentDocument: { exists: true };
    };

export function removeMemberWrite(leagueName: string, uid: string): WipeWrite {
  return {
    update: { name: leagueName },
    updateMask: { fieldPaths: [] },
    updateTransforms: [
      {
        fieldPath: 'memberUids',
        removeAllFromArray: { values: [{ stringValue: uid }] },
      },
    ],
    currentDocument: { exists: true },
  };
}

/**
 * Leagues: the ones [uid] owns are deleted with their invite codes; in the
 * others [uid] is taken out of `memberUids`.
 */
export async function collectLeagueWrites(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
}): Promise<{ deletes: string[]; updates: WipeWrite[] }> {
  const { projectId, accessToken, uid } = opts;
  const owned = await queryDocs(accessToken, projectId, (after) =>
    fieldStructuredQuery('leagues', 'ownerUid', 'EQUAL', uid, after),
  );
  const joined = await queryDocs(accessToken, projectId, (after) =>
    fieldStructuredQuery('leagues', 'memberUids', 'ARRAY_CONTAINS', uid, after),
  );
  const deletes: string[] = [];
  const ownedNames = new Set<string>();
  for (const league of owned) {
    ownedNames.add(league.name);
    deletes.push(league.name);
    const code = stringField(league.fields, 'code');
    if (code && /^[A-Z0-9]{1,16}$/.test(code)) {
      deletes.push(leagueCodePath(projectId, code));
    }
  }
  const updates = joined
    .filter((league) => !ownedNames.has(league.name))
    .map((league) => removeMemberWrite(league.name, uid));
  return { deletes, updates };
}

/** Every doc that holds [uid]'s data. Deleting a doc that doesn't exist is a no-op. */
export async function collectUserDocNames(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
}): Promise<string[]> {
  const { projectId, accessToken, uid } = opts;
  const base = documentsBase(projectId);
  const names = new Set<string>();

  const userPath = userDocPath(projectId, uid);
  for (const sub of USER_SUBCOLLECTIONS) {
    for (const name of await listDocumentNames(accessToken, `${userPath}/${sub}`)) {
      names.add(name);
    }
  }
  names.add(userPath);

  for (const root of WEEKLY_ROOTS) {
    for (const game of LEADERBOARD_GAMES) {
      const weeks = await listDocumentNames(
        accessToken,
        `${base}/${root}/${game}/weekly`,
        { showMissing: true },
      );
      for (const week of weeks) {
        names.add(
          weeklyEntryPath(projectId, root, game, docIdFromResourceName(week), uid),
        );
      }
    }
  }

  for (const root of LEADERBOARD_ROOTS) {
    for (const game of LEADERBOARD_GAMES) {
      names.add(allTimeLeaderboardPath(projectId, root, game, uid));
      const days = await listDocumentNames(
        accessToken,
        `${base}/${root}/${game}/daily`,
        { showMissing: true },
      );
      for (const day of days) {
        names.add(
          dailyEntryPath(projectId, root, game, docIdFromResourceName(day), uid),
        );
      }
    }
  }

  const activityDays = await listDocumentNames(
    accessToken,
    `${base}/daily_activity`,
    { showMissing: true },
  );
  for (const day of activityDays) {
    names.add(dailyActivityUserPath(projectId, docIdFromResourceName(day), uid));
  }

  for (const collectionId of UID_FIELD_COLLECTIONS) {
    for (const name of await queryNamesByUid(
      accessToken,
      projectId,
      collectionId,
      uid,
    )) {
      names.add(name);
    }
  }

  return [...names];
}

/** Applies [writes] in `batchWrite` calls of [DELETE_BATCH_SIZE]; throws if any write fails. */
export async function batchWriteAll(
  accessToken: string,
  projectId: string,
  writes: WipeWrite[],
): Promise<void> {
  const url = `${FIRESTORE_API}/${documentsBase(projectId)}:batchWrite`;
  for (let i = 0; i < writes.length; i += DELETE_BATCH_SIZE) {
    const chunk = writes.slice(i, i + DELETE_BATCH_SIZE);
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
      throw new Error(`firestore_batch_failed:${res.status}:${text.slice(0, 300)}`);
    }
    // batchWrite isn't atomic: each write reports its own status.
    const json = JSON.parse(text) as { status?: Array<{ code?: number }> };
    const failed = (json.status ?? []).filter((s) => (s.code ?? 0) !== 0);
    if (failed.length > 0) {
      throw new Error(`firestore_delete_failed:${failed.length}_of_${chunk.length}`);
    }
  }
}

/** Deletes [names] in `batchWrite` calls of [DELETE_BATCH_SIZE]; throws if any delete fails. */
export async function batchDelete(
  accessToken: string,
  projectId: string,
  names: string[],
): Promise<void> {
  await batchWriteAll(
    accessToken,
    projectId,
    names.map((name) => ({ delete: name })),
  );
}

export async function wipeUserFirestore(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
}): Promise<WipeResult> {
  if (!UID_PATTERN.test(opts.uid)) {
    return { ok: false, errorMessage: 'invalid_uid' };
  }
  try {
    const names = new Set(await collectUserDocNames(opts));
    const leagues = await collectLeagueWrites(opts);
    for (const name of leagues.deletes) names.add(name);
    const writes: WipeWrite[] = [
      ...leagues.updates,
      ...[...names].map((name) => ({ delete: name })),
    ];
    await batchWriteAll(opts.accessToken, opts.projectId, writes);
    return { ok: true, deleted: names.size };
  } catch (e) {
    return {
      ok: false,
      errorMessage: e instanceof Error ? e.message : 'firestore_wipe_failed',
    };
  }
}
