import { LEADERBOARD_GAMES, userDocPath } from './paths';

const FIRESTORE_API = 'https://firestore.googleapis.com/v1';

const USER_SUBCOLLECTIONS = [
  'game_days',
  'game_days_debug',
  'game_streaks',
  'game_streaks_debug',
] as const;

const LEADERBOARD_ROOTS = ['leaderboards', 'leaderboards_debug'] as const;

const LIST_PAGE_SIZE = 300;
const DAILY_ACTIVITY_PAGE_SIZE = 100;
const DAILY_ACTIVITY_MAX_PAGES = 60;

export type WipeResult = {
  ok: boolean;
  errorMessage?: string;
  softWarnings?: string[];
};

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
  return `${documentsBase(projectId)}/${root}/${game}/all_time/${encodeURIComponent(uid)}`;
}

export function dailyEntryPath(
  projectId: string,
  root: LeaderboardRoot,
  game: string,
  dayId: string,
  uid: string,
): string {
  return `${documentsBase(projectId)}/${root}/${game}/daily/${dayId}/entries/${encodeURIComponent(uid)}`;
}

function dailyActivityUserPath(
  projectId: string,
  dayId: string,
  uid: string,
): string {
  return `${documentsBase(projectId)}/daily_activity/${dayId}/users/${encodeURIComponent(uid)}`;
}

async function deleteDocument(
  accessToken: string,
  resourcePath: string,
): Promise<void> {
  const res = await fetch(`${FIRESTORE_API}/${resourcePath}`, {
    method: 'DELETE',
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (res.status === 404) return;
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`firestore_delete_failed:${res.status}:${text.slice(0, 300)}`);
  }
}

async function listDocumentNames(
  accessToken: string,
  collectionPath: string,
  pageSize: number,
  maxPages?: number,
): Promise<string[]> {
  const names: string[] = [];
  let pageToken: string | undefined;
  let pages = 0;

  do {
    if (maxPages !== undefined && pages >= maxPages) break;
    pages += 1;

    const qs = new URLSearchParams({ pageSize: String(pageSize) });
    if (pageToken) qs.set('pageToken', pageToken);
    const url = `${FIRESTORE_API}/${collectionPath}?${qs.toString()}`;
    const res = await fetch(url, {
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

async function deleteAllInCollection(
  accessToken: string,
  collectionPath: string,
): Promise<void> {
  const names = await listDocumentNames(
    accessToken,
    collectionPath,
    LIST_PAGE_SIZE,
  );
  for (const name of names) {
    await deleteDocument(accessToken, name);
  }
}

async function deleteUserSubcollections(
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const userPath = userDocPath(projectId, uid);
  for (const sub of USER_SUBCOLLECTIONS) {
    await deleteAllInCollection(accessToken, `${userPath}/${sub}`);
  }
}

async function wipeLeaderboards(
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const base = documentsBase(projectId);
  for (const root of LEADERBOARD_ROOTS) {
    for (const game of LEADERBOARD_GAMES) {
      await deleteDocument(
        accessToken,
        allTimeLeaderboardPath(projectId, root, game, uid),
      );

      const dailyCol = `${base}/${root}/${game}/daily`;
      const dayDocNames = await listDocumentNames(
        accessToken,
        dailyCol,
        LIST_PAGE_SIZE,
      );
      for (const dayName of dayDocNames) {
        const dayId = docIdFromResourceName(dayName);
        await deleteDocument(
          accessToken,
          dailyEntryPath(projectId, root, game, dayId, uid),
        );
      }
    }
  }
}

async function deleteIssueReportsForUid(
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<void> {
  const url = `${FIRESTORE_API}/${documentsBase(projectId)}:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: 'issue_reports' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'uid' },
          op: 'EQUAL',
          value: { stringValue: uid },
        },
      },
    },
  };
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`firestore_query_failed:${res.status}:${text.slice(0, 300)}`);
  }
  const rows = JSON.parse(text) as Array<{
    document?: { name: string };
  }>;
  for (const row of rows) {
    const name = row.document?.name;
    if (name) await deleteDocument(accessToken, name);
  }
}

async function wipeDailyActivityBestEffort(
  accessToken: string,
  projectId: string,
  uid: string,
): Promise<string | null> {
  try {
    const col = `${documentsBase(projectId)}/daily_activity`;
    const dayNames = await listDocumentNames(
      accessToken,
      col,
      DAILY_ACTIVITY_PAGE_SIZE,
      DAILY_ACTIVITY_MAX_PAGES,
    );
    for (const dayName of dayNames) {
      const dayId = docIdFromResourceName(dayName);
      await deleteDocument(
        accessToken,
        dailyActivityUserPath(projectId, dayId, uid),
      );
    }
    return null;
  } catch {
    return 'daily_activity_partial';
  }
}

export async function wipeUserFirestore(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
}): Promise<WipeResult> {
  const softWarnings: string[] = [];

  try {
    await deleteUserSubcollections(
      opts.accessToken,
      opts.projectId,
      opts.uid,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'user_subcollections_failed';
    return { ok: false, errorMessage: msg };
  }

  try {
    await deleteDocument(
      opts.accessToken,
      userDocPath(opts.projectId, opts.uid),
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'user_doc_delete_failed';
    return { ok: false, errorMessage: msg };
  }

  try {
    await wipeLeaderboards(opts.accessToken, opts.projectId, opts.uid);
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'leaderboards_wipe_failed';
    return { ok: false, errorMessage: msg };
  }

  try {
    await deleteIssueReportsForUid(
      opts.accessToken,
      opts.projectId,
      opts.uid,
    );
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'issue_reports_delete_failed';
    return { ok: false, errorMessage: msg };
  }

  const dailyWarning = await wipeDailyActivityBestEffort(
    opts.accessToken,
    opts.projectId,
    opts.uid,
  );
  if (dailyWarning) softWarnings.push(dailyWarning);

  return softWarnings.length > 0
    ? { ok: true, softWarnings }
    : { ok: true };
}
