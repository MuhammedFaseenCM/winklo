import { getGoogleAccessToken, parseServiceAccountJson } from './google_auth';
import { parseOpen, recordGuestOpen } from './open';

/** The slice of a Workers Rate Limiting binding this Worker uses. */
export type Limiter = { limit(options: { key: string }): Promise<{ success: boolean }> };

export interface Env {
  FIREBASE_PROJECT_ID: string;
  FIREBASE_SERVICE_ACCOUNT_JSON: string;
  /** 30 / 60 s per client IP (wrangler.toml). */
  IP_LIMIT?: Limiter;
  /** 6 / 60 s per install ID. */
  INSTALL_LIMIT?: Limiter;
}

/** What the route needs from outside, injectable for tests. */
export type Deps = {
  now: () => number;
  accessToken: (env: Env) => Promise<string>;
};

const defaultDeps: Deps = {
  now: Date.now,
  accessToken: (env) => getGoogleAccessToken(parseServiceAccountJson(env.FIREBASE_SERVICE_ACCOUNT_JSON)),
};

/** An open is under 200 bytes; anything far bigger is refused unread. */
export const MAX_BODY_BYTES = 2 * 1024;

function json(body: unknown, status = 200): Response {
  return Response.json(body, { status });
}

/** A missing or failing limiter lets the open through: counting matters more than the brake. */
async function allowed(limiter: Limiter | undefined, key: string): Promise<boolean> {
  if (!limiter) return true;
  try {
    return (await limiter.limit({ key })).success;
  } catch (e) {
    console.error('rate_limit_failed', e instanceof Error ? e.message : e);
    return true;
  }
}

export async function route(request: Request, env: Env, deps: Deps = defaultDeps): Promise<Response> {
  const { pathname } = new URL(request.url);
  if (request.method === 'GET' && pathname === '/v1/health') return json({ ok: true });
  if (request.method !== 'POST' || pathname !== '/v1/open') return new Response('Not found', { status: 404 });

  const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
  if (!(await allowed(env.IP_LIMIT, `ip:${ip}`))) return json({ error: 'rate_limited' }, 429);

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
  const open = parseOpen(body, deps.now());
  if (!open) return json({ error: 'bad_request' }, 400);

  if (!(await allowed(env.INSTALL_LIMIT, `install:${open.installId}`))) return json({ error: 'rate_limited' }, 429);

  try {
    const accessToken = await deps.accessToken(env);
    await recordGuestOpen({ projectId: env.FIREBASE_PROJECT_ID, accessToken, open });
  } catch (e) {
    console.error('guest_open_failed', e instanceof Error ? e.message : e);
    return json({ error: 'unavailable' }, 503);
  }
  return json({ ok: true });
}

export default {
  fetch(request: Request, env: Env): Promise<Response> {
    return route(request, env);
  },
} satisfies ExportedHandler<Env>;
