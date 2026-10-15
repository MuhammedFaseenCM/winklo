import { afterEach, describe, expect, it, vi } from 'vitest';
import {
  ContentionError,
  batchGet,
  commit,
  decodeFields,
  decodeValue,
  encodeFields,
  encodeValue,
} from './firestore';

describe('values', () => {
  it('round-trips the shapes the boards use', () => {
    const data = {
      n: 12,
      f: 1.5,
      s: 'Ada',
      b: false,
      z: null,
      list: [1, 'a', { row: 0, col: 1 }],
      days: { '2026-10-12': 61, '2026-10-13': 75 },
    };
    expect(decodeFields(encodeFields(data))).toEqual(data);
  });

  it('decodes timestamps as strings and integers as numbers', () => {
    expect(decodeValue({ timestampValue: '2026-10-15T10:00:00Z' })).toBe(
      '2026-10-15T10:00:00Z',
    );
    expect(decodeValue({ integerValue: '42' })).toBe(42);
    expect(encodeValue(42)).toEqual({ integerValue: '42' });
  });
});

describe('batchGet', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('maps found and missing docs by name', async () => {
    const fetchMock = vi.fn(async () =>
      Response.json([
        {
          found: {
            name: 'a',
            fields: { timeSeconds: { integerValue: '30' } },
            updateTime: '2026-10-15T10:00:00.123456Z',
          },
        },
        { missing: 'b' },
      ]),
    );
    vi.stubGlobal('fetch', fetchMock);
    const docs = await batchGet({ projectId: 'p', accessToken: 't', names: ['a', 'b'] });
    expect(docs.get('a')).toEqual({
      data: { timeSeconds: 30 },
      updateTime: '2026-10-15T10:00:00.123456Z',
    });
    expect(docs.get('b')).toBeNull();
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });
});

describe('commit', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('throws ContentionError when a precondition fails', async () => {
    for (const [status, code] of [
      [400, 'FAILED_PRECONDITION'],
      [409, 'ALREADY_EXISTS'],
      [409, 'ABORTED'],
    ] as const) {
      vi.stubGlobal(
        'fetch',
        vi.fn(async () => Response.json({ error: { status: code } }, { status })),
      );
      await expect(
        commit({ projectId: 'p', accessToken: 't', writes: [] }),
      ).rejects.toBeInstanceOf(ContentionError);
    }
  });

  it('throws a plain error for anything else', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async () => Response.json({ error: { status: 'PERMISSION_DENIED' } }, { status: 403 })),
    );
    const error = await commit({ projectId: 'p', accessToken: 't', writes: [] }).catch(
      (e: unknown) => e,
    );
    expect(error).toBeInstanceOf(Error);
    expect(error).not.toBeInstanceOf(ContentionError);
  });
});
