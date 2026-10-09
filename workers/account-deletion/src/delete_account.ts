import { deleteAuthUser } from './auth_delete';
import { writeDeletionAudit } from './audit';
import { wipeUserFirestore } from './firestore_wipe';
import {
  getGoogleAccessToken,
  parseServiceAccountJson,
} from './google_auth';
import { avatarObjectKey } from './paths';

export interface Env {
  AVATARS: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  FIREBASE_SERVICE_ACCOUNT_JSON: string;
}

export type DeletionSteps = {
  firestore: boolean;
  r2: boolean;
  auth: boolean;
};

export function summarizeStatus(
  steps: DeletionSteps,
): 'completed' | 'partial' | 'failed' {
  if (steps.firestore && steps.r2 && steps.auth) return 'completed';
  if (!steps.firestore && !steps.auth) return 'failed';
  return 'partial';
}

export async function runDeleteAccount(opts: {
  env: Env;
  uid: string;
  email: string | null;
}): Promise<{ httpStatus: number; body: { ok?: true; error?: string } }> {
  const { env, uid, email } = opts;
  const requestedAt = new Date().toISOString();
  const steps: DeletionSteps = { firestore: false, r2: false, auth: false };
  const softWarnings: string[] = [];
  let errorMessage: string | null = null;

  try {
    await env.AVATARS.delete(avatarObjectKey(uid));
    steps.r2 = true;
  } catch {
    steps.r2 = false;
  }

  let accessToken: string | null = null;
  try {
    const sa = parseServiceAccountJson(env.FIREBASE_SERVICE_ACCOUNT_JSON);
    accessToken = await getGoogleAccessToken(sa);
  } catch (e) {
    errorMessage = e instanceof Error ? e.message : 'token_failed';
  }

  const projectId = env.FIREBASE_PROJECT_ID;

  if (accessToken) {
    const wipeResult = await wipeUserFirestore({
      projectId,
      accessToken,
      uid,
    });
    steps.firestore = wipeResult.ok;
    if (!wipeResult.ok) {
      errorMessage = wipeResult.errorMessage ?? 'firestore_wipe_failed';
    } else if (wipeResult.softWarnings?.length) {
      softWarnings.push(...wipeResult.softWarnings);
    }

    try {
      await deleteAuthUser({ projectId, accessToken, uid });
      steps.auth = true;
    } catch (e) {
      steps.auth = false;
      const msg = e instanceof Error ? e.message : 'auth_delete_failed';
      errorMessage = errorMessage ? `${errorMessage}; ${msg}` : msg;
    }
  }

  let status = summarizeStatus(steps);
  if (softWarnings.length > 0 && status === 'completed') {
    status = 'partial';
  }
  if (softWarnings.length > 0 && errorMessage === null) {
    errorMessage = softWarnings.join(', ');
  }

  const completedAt = new Date().toISOString();

  if (accessToken) {
    try {
      await writeDeletionAudit({
        projectId,
        accessToken,
        uid,
        email,
        requestedAt,
        completedAt,
        status,
        steps,
        errorMessage,
      });
    } catch (e) {
      console.error('deletion_audit_failed', e);
    }
  }

  if (status === 'failed') {
    return { httpStatus: 500, body: { error: 'delete_failed' } };
  }
  return { httpStatus: 200, body: { ok: true } };
}
