/**
 * The few Firestore REST calls the Worker needs: one `batchGet` for every
 * doc a submission reads and one `commit` for every write, so a submission
 * stays far inside the Workers Free plan's 50 subrequests.
 */

const FIRESTORE_API = 'https://firestore.googleapis.com/v1';

export type FirestoreValue = Record<string, unknown>;

export function documentsBase(projectId: string): string {
  return `projects/${projectId}/databases/(default)/documents`;
}

/** A Firestore REST value as plain JSON (integers as numbers, timestamps as strings). */
export function decodeValue(value: unknown): unknown {
  if (!value || typeof value !== 'object') return null;
  const v = value as Record<string, unknown>;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return Number(v.doubleValue);
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('nullValue' in v) return null;
  if ('arrayValue' in v) {
    const values = (v.arrayValue as { values?: unknown[] } | undefined)?.values ?? [];
    return values.map(decodeValue);
  }
  if ('mapValue' in v) {
    const fields = (v.mapValue as { fields?: Record<string, unknown> } | undefined)?.fields;
    return decodeFields(fields);
  }
  return null;
}

export function decodeFields(
  fields: Record<string, unknown> | undefined,
): Record<string, unknown> {
  const data: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(fields ?? {})) data[k] = decodeValue(v);
  return data;
}

export function encodeValue(value: unknown): FirestoreValue {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(encodeValue) } };
  }
  if (typeof value === 'object') {
    return { mapValue: { fields: encodeFields(value as Record<string, unknown>) } };
  }
  throw new Error(`Cannot encode ${typeof value}`);
}

export function encodeFields(
  data: Record<string, unknown>,
): Record<string, FirestoreValue> {
  const fields: Record<string, FirestoreValue> = {};
  for (const [k, v] of Object.entries(data)) fields[k] = encodeValue(v);
  return fields;
}

export type StoredDoc = { data: Record<string, unknown>; updateTime: string };

/** Reads [names] (full resource names) in one call; a missing doc maps to null. */
export async function batchGet(opts: {
  projectId: string;
  accessToken: string;
  names: string[];
}): Promise<Map<string, StoredDoc | null>> {
  const res = await fetch(
    `${FIRESTORE_API}/${documentsBase(opts.projectId)}:batchGet`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${opts.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ documents: opts.names }),
    },
  );
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`firestore_batch_get_failed:${res.status}:${text.slice(0, 300)}`);
  }
  const rows = JSON.parse(text) as Array<{
    found?: { name: string; fields?: Record<string, unknown>; updateTime: string };
    missing?: string;
  }>;
  const docs = new Map<string, StoredDoc | null>();
  for (const name of opts.names) docs.set(name, null);
  for (const row of rows) {
    if (row.found) {
      docs.set(row.found.name, {
        data: decodeFields(row.found.fields),
        updateTime: row.found.updateTime,
      });
    }
  }
  return docs;
}

export type Precondition = { exists: false } | { updateTime: string };

export type CommitWrite = {
  update: { name: string; fields: Record<string, FirestoreValue> };
  updateMask: { fieldPaths: string[] };
  updateTransforms?: Array<{ fieldPath: string; setToServerValue: 'REQUEST_TIME' }>;
  currentDocument: Precondition;
};

/** A doc changed (or appeared) between the read and the commit. */
export class ContentionError extends Error {
  constructor(detail: string) {
    super(`firestore_contention:${detail}`);
  }
}

/** Status codes Firestore uses when a precondition no longer holds. */
const CONTENTION_STATUSES = new Set(['ABORTED', 'ALREADY_EXISTS', 'FAILED_PRECONDITION', 'NOT_FOUND']);

/** Applies [writes] atomically; throws [ContentionError] when a precondition failed. */
export async function commit(opts: {
  projectId: string;
  accessToken: string;
  writes: CommitWrite[];
}): Promise<void> {
  const res = await fetch(
    `${FIRESTORE_API}/${documentsBase(opts.projectId)}:commit`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${opts.accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ writes: opts.writes }),
    },
  );
  if (res.ok) {
    await res.text();
    return;
  }
  const text = await res.text();
  let status = '';
  try {
    status = (JSON.parse(text) as { error?: { status?: string } }).error?.status ?? '';
  } catch {
    // Not JSON; fall through to a plain failure.
  }
  if (CONTENTION_STATUSES.has(status)) throw new ContentionError(status);
  throw new Error(`firestore_commit_failed:${res.status}:${text.slice(0, 300)}`);
}
