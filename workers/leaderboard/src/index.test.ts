import { describe, expect, it, vi } from 'vitest';
import { MAX_BODY_BYTES, route, type Env } from './index';

const env: Env = { FIREBASE_PROJECT_ID: 'p', FIREBASE_SERVICE_ACCOUNT_JSON: '' };

function post(body: string, headers: Record<string, string> = {}) {
  return new Request('https://w.example/v1/submit', { method: 'POST', body, headers });
}

describe('route', () => {
  it('answers the health check', async () => {
    const res = await route(new Request('https://w.example/v1/health'), env);
    expect(res.status).toBe(200);
  });

  it('404s anything else', async () => {
    expect((await route(new Request('https://w.example/v1/submit'), env)).status).toBe(404);
    expect((await route(new Request('https://w.example/x', { method: 'POST' }), env)).status).toBe(404);
  });

  it('401s a missing or bad token before reading the body', async () => {
    const verify = vi.fn(async () => {
      throw new Error('bad');
    });
    expect((await route(post('{}'), env, verify)).status).toBe(401);
    expect(verify).not.toHaveBeenCalled();
    const res = await route(post('{}', { Authorization: 'Bearer nope' }), env, verify);
    expect(res.status).toBe(401);
    expect(await res.json()).toEqual({ error: 'unauthorized' });
  });

  it('400s a body that is not JSON or too big', async () => {
    const verify = async () => ({ uid: 'u1' });
    const auth = { Authorization: 'Bearer ok' };
    const notJson = await route(post('{', auth), env, verify);
    expect(notJson.status).toBe(400);
    expect(await notJson.json()).toEqual({ error: 'bad_request' });
    const big = await route(post('x'.repeat(MAX_BODY_BYTES + 1), auth), env, verify);
    expect(big.status).toBe(400);
  });

  it('500s without the service account, so the app falls back', async () => {
    const res = await route(
      post('{}', { Authorization: 'Bearer ok' }),
      env,
      async () => ({ uid: 'u1' }),
    );
    expect(res.status).toBe(500);
  });
});
