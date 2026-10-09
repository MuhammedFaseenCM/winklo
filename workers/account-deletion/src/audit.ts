type FirestoreValue = Record<string, unknown>;

function stringOrNull(value: string | null): FirestoreValue {
  if (value === null) return { nullValue: null };
  return { stringValue: value };
}

export async function writeDeletionAudit(opts: {
  projectId: string;
  accessToken: string;
  uid: string;
  email: string | null;
  requestedAt: string;
  completedAt: string;
  status: 'completed' | 'partial' | 'failed';
  steps: { firestore: boolean; r2: boolean; auth: boolean };
  errorMessage: string | null;
}): Promise<void> {
  const url = `https://firestore.googleapis.com/v1/projects/${opts.projectId}/databases/(default)/documents/deletion_requests`;
  const fields: Record<string, FirestoreValue> = {
    uid: { stringValue: opts.uid },
    email: stringOrNull(opts.email),
    requestedAt: { timestampValue: opts.requestedAt },
    completedAt: { timestampValue: opts.completedAt },
    status: { stringValue: opts.status },
    steps: {
      mapValue: {
        fields: {
          firestore: { booleanValue: opts.steps.firestore },
          r2: { booleanValue: opts.steps.r2 },
          auth: { booleanValue: opts.steps.auth },
        },
      },
    },
    errorMessage: stringOrNull(opts.errorMessage),
  };
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${opts.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ fields }),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`firestore_audit_failed:${res.status}:${text.slice(0, 300)}`);
  }
}
