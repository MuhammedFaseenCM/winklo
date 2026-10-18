import { afterEach, describe, expect, it, vi } from 'vitest';
import { ContentionError, commit, documentsBase, encodeFields } from './firestore';

afterEach(() => vi.unstubAllGlobals());

describe('encodeFields', () => {
  it('encodes integers, strings and null', () => {
    expect(encodeFields({ opens: 1, platform: 'android', x: null })).toEqual({
      opens: { integerValue: '1' },
      platform: { stringValue: 'android' },
      x: { nullValue: null },
    });
  });
});

describe('commit', () => {
  const write = {
    update: { name: `${documentsBase('p')}/daily_activity/2026-10-17/guests/g`, fields: {} },
    currentDocument: { exists: false } as const,
  };

  it('posts the writes to :commit with the token', async () => {
    const fetchMock = vi.fn(async () => Response.json({ writeResults: [] }));
    vi.stubGlobal('fetch', fetchMock);
    await commit({ projectId: 'p', accessToken: 't', writes: [write] });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://firestore.googleapis.com/v1/projects/p/databases/(default)/documents:commit');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer t');
    expect(JSON.parse(String(init.body))).toEqual({ writes: [write] });
  });

  it('throws ContentionError when a precondition fails', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => Response.json({ error: { status: 'ALREADY_EXISTS' } }, { status: 409 })),
    );
    await expect(commit({ projectId: 'p', accessToken: 't', writes: [write] })).rejects.toBeInstanceOf(
      ContentionError,
    );
  });

  it('throws a plain error for any other failure', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('boom', { status: 500 })));
    const error = await commit({ projectId: 'p', accessToken: 't', writes: [write] }).catch((e) => e);
    expect(error).not.toBeInstanceOf(ContentionError);
    expect(String(error)).toMatch(/firestore_commit_failed:500/);
  });
});
