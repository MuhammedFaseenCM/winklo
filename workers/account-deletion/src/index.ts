import { corsHeadersFor, isOriginAllowed } from './cors';
import { type Env, runDeleteAccount } from './delete_account';
import { verifyFirebaseIdToken } from './firebase_auth';

export type { Env };

function parseBearer(request: Request): string | null {
  const header = request.headers.get('Authorization');
  if (!header?.startsWith('Bearer ')) return null;
  const token = header.slice('Bearer '.length).trim();
  return token || null;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const origin = request.headers.get('Origin');
    const cors = corsHeadersFor(origin);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors });
    }

    if (
      request.method === 'GET' &&
      new URL(request.url).pathname === '/v1/health'
    ) {
      return Response.json({ ok: true }, { headers: cors });
    }

    if (
      request.method !== 'POST' ||
      new URL(request.url).pathname !== '/v1/delete-account'
    ) {
      return new Response('Not found', { status: 404, headers: cors });
    }

    if (origin && !isOriginAllowed(origin)) {
      return Response.json(
        { error: 'origin_not_allowed' },
        { status: 403, headers: cors },
      );
    }

    const token = parseBearer(request);
    if (!token) {
      return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });
    }

    let uid: string;
    let email: string | null;
    try {
      ({ uid, email } = await verifyFirebaseIdToken(
        token,
        env.FIREBASE_PROJECT_ID,
      ));
    } catch {
      return Response.json({ error: 'unauthorized' }, { status: 401, headers: cors });
    }

    let body: { confirm?: string };
    try {
      body = (await request.json()) as { confirm?: string };
    } catch {
      return Response.json({ error: 'invalid_json' }, { status: 400, headers: cors });
    }
    if (body.confirm !== 'DELETE') {
      return Response.json(
        { error: 'confirm_required' },
        { status: 400, headers: cors },
      );
    }

    if (!env.FIREBASE_SERVICE_ACCOUNT_JSON?.trim()) {
      return Response.json(
        { error: 'misconfigured' },
        { status: 500, headers: cors },
      );
    }

    const result = await runDeleteAccount({ env, uid, email });
    return Response.json(result.body, {
      status: result.httpStatus,
      headers: cors,
    });
  },
};
