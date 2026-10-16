import { afterEach, describe, expect, it, vi } from 'vitest';
import { MAX_BODY_BYTES, route, type Deps, type Env, type Limiter } from './index';

const NOW = Date.parse('2026-10-17T10:00:00Z');
const ID = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const good = { installId: ID, dayId: '2026-10-17', platform: 'ios', appVersion: '1.1.0', build: 19 };

function limiter(success = true): Limiter & { keys: string[] } {
  const keys: string[] = [];
  return {
    keys,
    limit: vi.fn(async ({ key }: { key: string }) => {
      keys.push(key);
      return { success };
    }),
  };
}

function env(patch: Partial<Env> = {}): Env {
  return {
    FIREBASE_PROJECT_ID: 'p',
    FIREBASE_SERVICE_ACCOUNT_JSON: '{}',
    IP_LIMIT: limiter(),
    INSTALL_LIMIT: limiter(),
    NEW_GUEST_LIMIT: limiter(),
    ...patch,
  };
}

const deps: Deps = { now: () => NOW, accessToken: async () => 'tok' };

function post(body: unknown, headers: Record<string, string> = {}): Request {
  return new Request('https://activity.example/v1/open', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'CF-Connecting-IP': '203.0.113.9', ...headers },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });
}

afterEach(() => vi.unstubAllGlobals());

describe('route', () => {
  it('answers the health check', async () => {
    const res = await route(new Request('https://activity.example/v1/health'), env(), deps);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
  });

  it('404s anything else', async () => {
    const res = await route(new Request('https://activity.example/v1/open'), env(), deps);
    expect(res.status).toBe(404);
  });

  it('records a good open and says ok', async () => {
    const fetchMock = vi.fn(async () => Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    const e = env();
    const res = await route(post(good), e, deps);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect((e.IP_LIMIT as ReturnType<typeof limiter>).keys).toEqual(['ip:203.0.113.9']);
    expect((e.INSTALL_LIMIT as ReturnType<typeof limiter>).keys).toEqual([`install:${ID}`]);
    // A repeat open never asks the new-guest limiter.
    expect((e.NEW_GUEST_LIMIT as ReturnType<typeof limiter>).keys).toEqual([]);
  });

  it('keys the IP limit on the /64 for IPv6', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Response.json({})));
    const e = env();
    await route(post(good, { 'CF-Connecting-IP': '2001:db8:1:2:aaaa:bbbb:cccc:dddd' }), e, deps);
    expect((e.IP_LIMIT as ReturnType<typeof limiter>).keys).toEqual(['ip:2001:db8:1:2::/64']);
  });

  it('a new guest asks the new-guest limiter, keyed by client, then is created', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ error: { status: 'NOT_FOUND' } }, { status: 404 }))
      .mockResolvedValueOnce(Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    const e = env();
    const res = await route(post(good, { 'CF-Connecting-IP': '2001:db8:1:2::9' }), e, deps);
    expect(res.status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect((e.NEW_GUEST_LIMIT as ReturnType<typeof limiter>).keys).toEqual(['new:2001:db8:1:2::/64']);
  });

  it('429s a new guest over the new-guest limit, without creating', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ error: { status: 'NOT_FOUND' } }, { status: 404 }));
    vi.stubGlobal('fetch', fetchMock);
    const res = await route(post(good), env({ NEW_GUEST_LIMIT: limiter(false) }), deps);
    expect(res.status).toBe(429);
    expect(await res.json()).toEqual({ error: 'rate_limited' });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('a repeat open is not held back by the new-guest limit', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Response.json({})));
    const res = await route(post(good), env({ NEW_GUEST_LIMIT: limiter(false) }), deps);
    expect(res.status).toBe(200);
  });

  it('refuses a bad body with 400 and writes nothing', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    for (const body of ['not json', { ...good, platform: 'web' }]) {
      const res = await route(post(body), env(), deps);
      expect(res.status).toBe(400);
      expect(await res.json()).toEqual({ error: 'bad_request' });
    }
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('refuses a body over the size limit', async () => {
    const res = await route(post({ ...good, pad: 'x'.repeat(MAX_BODY_BYTES) }), env(), deps);
    expect(res.status).toBe(400);
  });

  it('refuses a streamed body over the limit when no Content-Length is sent', async () => {
    const chunk = new TextEncoder().encode('x'.repeat(1024));
    let sent = 0;
    let cancelled = false;
    const stream = new ReadableStream<Uint8Array>({
      pull(controller) {
        if (sent >= 100) return controller.close();
        sent++;
        controller.enqueue(chunk);
      },
      cancel() {
        cancelled = true;
      },
    });
    const req = new Request('https://activity.example/v1/open', {
      method: 'POST',
      headers: { 'CF-Connecting-IP': '203.0.113.9' },
      body: stream,
      duplex: 'half',
    } as RequestInit);
    expect(req.headers.get('Content-Length')).toBeNull();
    const res = await route(req, env(), deps);
    expect(res.status).toBe(400);
    expect(sent).toBeLessThan(10);
    expect(cancelled).toBe(true);
  });

  it('429s when the IP is over its limit, before reading the body', async () => {
    const install = limiter();
    const res = await route(post(good), env({ IP_LIMIT: limiter(false), INSTALL_LIMIT: install }), deps);
    expect(res.status).toBe(429);
    expect(await res.json()).toEqual({ error: 'rate_limited' });
    expect(install.keys).toEqual([]);
  });

  it('429s when the install is over its limit', async () => {
    const res = await route(post(good), env({ INSTALL_LIMIT: limiter(false) }), deps);
    expect(res.status).toBe(429);
  });

  it('still records when a limiter is missing or fails', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => Response.json({})));
    const broken: Limiter = { limit: async () => Promise.reject(new Error('down')) };
    const res = await route(post(good), env({ IP_LIMIT: undefined, INSTALL_LIMIT: broken }), deps);
    expect(res.status).toBe(200);
    // A new guest with a missing or failing new-guest limiter is still created.
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(Response.json({ error: { status: 'NOT_FOUND' } }, { status: 404 }))
      .mockResolvedValueOnce(Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    expect((await route(post(good), env({ NEW_GUEST_LIMIT: broken }), deps)).status).toBe(200);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it('503s when Firestore or the token fails', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('down', { status: 500 })));
    expect((await route(post(good), env(), deps)).status).toBe(503);
    const noToken: Deps = { now: () => NOW, accessToken: async () => Promise.reject(new Error('bad sa')) };
    const res = await route(post(good), env(), noToken);
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: 'unavailable' });
  });
});
