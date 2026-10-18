import { errors } from 'jose';

import { verifyFirebaseIdToken } from './firebase_auth';
import { getGoogleAccessToken, parseServiceAccountJson } from './google_auth';
import { handleSubmit } from './submit';

export interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_SERVICE_ACCOUNT_JSON: string;
}

/** Proofs are a few hundred bytes; anything far bigger is refused unread. */
export const MAX_BODY_BYTES = 32 * 1024;

type Verify = (token: string, projectId: string) => Promise<{ uid: string }>;

/** jose errors that mean the token itself is bad, not that checking it failed. */
const BAD_TOKEN_CODES = new Set([
  'ERR_JWT_EXPIRED',
  'ERR_JWT_CLAIM_VALIDATION_FAILED',
  'ERR_JWT_INVALID',
  'ERR_JWS_INVALID',
  'ERR_JWS_SIGNATURE_VERIFICATION_FAILED',
  'ERR_JWKS_NO_MATCHING_KEY',
  'ERR_JOSE_ALG_NOT_ALLOWED',
  'ERR_JOSE_NOT_SUPPORTED',
]);

/**
 * A bad token is a 401 (final for the app). Anything else, such as Google's
 * key set not loading, is a 503 so the app writes the clear another way.
 */
export function isBadTokenError(error: unknown): boolean {
  if (error instanceof errors.JOSEError) return BAD_TOKEN_CODES.has(error.code);
  return error instanceof Error && error.message === 'missing sub';
}

function parseBearer(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token || null;
}

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

/** The Worker, with the token check injectable for tests. */
export async function route(
  request: Request,
  env: Env,
  verify: Verify = verifyFirebaseIdToken,
): Promise<Response> {
  const { pathname } = new URL(request.url);
  if (request.method === 'GET' && pathname === '/v1/health') {
    return json({ ok: true });
  }
  if (request.method !== 'POST' || pathname !== '/v1/submit') {
    return new Response('Not found', { status: 404 });
  }

  const token = parseBearer(request);
  if (!token) return json({ error: 'unauthorized' }, 401);
  let uid: string;
  try {
    ({ uid } = await verify(token, env.FIREBASE_PROJECT_ID));
  } catch (e) {
    if (isBadTokenError(e)) return json({ error: 'unauthorized' }, 401);
    console.error('token_check_failed', e instanceof Error ? e.message : e);
    return json({ error: 'unavailable' }, 503);
  }

  const declared = Number(request.headers.get('Content-Length') ?? '0');
  if (declared > MAX_BODY_BYTES) return json({ error: 'bad_request' }, 400);
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) return json({ error: 'bad_request' }, 400);
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return json({ error: 'bad_request' }, 400);
  }

  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim()) {
    return json({ error: 'misconfigured' }, 500);
  }

  const result = await handleSubmit(
    {
      projectId: env.FIREBASE_PROJECT_ID,
      getAccessToken: () =>
        getGoogleAccessToken(parseServiceAccountJson(env.FIREBASE_SERVICE_ACCOUNT_JSON)),
      now: () => new Date(),
    },
    uid,
    body,
  );
  return json(result.body, result.status);
}

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return route(request, env);
  },
};
