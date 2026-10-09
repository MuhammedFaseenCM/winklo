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

function appendError(current: string | null, next: string): string {
  return current ? `${current}; ${next}` : next;
}

/**
 * Wipes the player's Firestore data and avatar, then deletes their Auth user.
 *
 * The Auth user goes last and only once everything else is gone: while it
 * exists the player can sign in again and retry, which a deleted account
 * can't. So the request succeeds only when every step does; anything less is
 * reported as `delete_failed` and is safe to retry.
 */
export async function runDeleteAccount(opts: {
  env: Env;
  uid: string;
  email: string | null;
}): Promise<{ httpStatus: number; body: { ok?: true; error?: string } }> {
  const { env, uid, email } = opts;
  const requestedAt = new Date().toISOString();
  const steps: DeletionSteps = { firestore: false, r2: false, auth: false };
  let errorMessage: string | null = null;
  const projectId = env.FIREBASE_PROJECT_ID;

  let accessToken: string | null = null;
  try {
    const sa = parseServiceAccountJson(env.FIREBASE_SERVICE_ACCOUNT_JSON);
    accessToken = await getGoogleAccessToken(sa);
  } catch (e) {
    errorMessage = e instanceof Error ? e.message : 'token_failed';
  }

  if (accessToken) {
    const wipe = await wipeUserFirestore({ projectId, accessToken, uid });
    steps.firestore = wipe.ok;
    if (!wipe.ok) errorMessage = appendError(errorMessage, wipe.errorMessage);
  }

  try {
    await env.AVATARS.delete(avatarObjectKey(uid));
    steps.r2 = true;
  } catch {
    errorMessage = appendError(errorMessage, 'r2_delete_failed');
  }

  if (accessToken && steps.firestore && steps.r2) {
    try {
      await deleteAuthUser({ projectId, accessToken, uid });
      steps.auth = true;
    } catch (e) {
      errorMessage = appendError(
        errorMessage,
        e instanceof Error ? e.message : 'auth_delete_failed',
      );
    }
  }

  const status = summarizeStatus(steps);

  if (accessToken) {
    try {
      await writeDeletionAudit({
        projectId,
        accessToken,
        uid,
        email,
        requestedAt,
        completedAt: new Date().toISOString(),
        status,
        steps,
        errorMessage,
      });
    } catch (e) {
      console.error('deletion_audit_failed', e);
    }
  }

  if (status !== 'completed') {
    return { httpStatus: 500, body: { error: 'delete_failed' } };
  }
  return { httpStatus: 200, body: { ok: true } };
}
