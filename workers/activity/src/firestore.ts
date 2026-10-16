/**
 * The Firestore REST calls this Worker needs: one `commit` per write, at most
 * two per open (create, then increment when the doc already exists).
 */

const FIRESTORE_API = 'https://firestore.googleapis.com/v1';

export type FirestoreValue = Record<string, unknown>;

export function documentsBase(projectId: string): string {
  return `projects/${projectId}/databases/(default)/documents`;
}

export function encodeValue(value: unknown): FirestoreValue {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  throw new Error(`Cannot encode ${typeof value}`);
}

export function encodeFields(data: Record<string, unknown>): Record<string, FirestoreValue> {
  const fields: Record<string, FirestoreValue> = {};
  for (const [k, v] of Object.entries(data)) fields[k] = encodeValue(v);
  return fields;
}

export type Precondition = { exists: boolean };

export type FieldTransform =
  | { fieldPath: string; setToServerValue: 'REQUEST_TIME' }
  | { fieldPath: string; increment: FirestoreValue };

export type CommitWrite = {
  update: { name: string; fields: Record<string, FirestoreValue> };
  /** Without a mask the write replaces the whole doc (used to create one). */
  updateMask?: { fieldPaths: string[] };
  updateTransforms?: FieldTransform[];
  currentDocument: Precondition;
};

/** A precondition no longer held: the doc appeared, or vanished, before the commit. */
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
  const res = await fetch(`${FIRESTORE_API}/${documentsBase(opts.projectId)}:commit`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${opts.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ writes: opts.writes }),
  });
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
