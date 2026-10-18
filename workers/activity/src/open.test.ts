import { afterEach, describe, expect, it, vi } from 'vitest';
import { clientKey, dayIsOpenNow, guestDocName, INSTALL_ID_PATTERN, parseOpen, recordGuestOpen } from './open';

const NOW = Date.parse('2026-10-17T10:00:00Z');
const ID = '3f2b8c1e-9a4d-4e7f-b123-0c9d8e7f6a5b';
const good = { installId: ID, dayId: '2026-10-17', platform: 'android', appVersion: '1.1.0', build: 19 };

describe('parseOpen', () => {
  it('accepts a well-formed open', () => {
    expect(parseOpen(good, NOW)).toEqual(good);
  });

  it.each([
    ['not an object', 'x'],
    ['an array', [good]],
    ['a non-v4 install id', { ...good, installId: '3f2b8c1e-9a4d-1e7f-b123-0c9d8e7f6a5b' }],
    ['an uppercase install id', { ...good, installId: ID.toUpperCase() }],
    ['a made-up day', { ...good, dayId: '2026-02-31' }],
    ['a day outside the window', { ...good, dayId: '2026-10-19' }],
    ['an unknown platform', { ...good, platform: 'web' }],
    ['an empty version', { ...good, appVersion: '' }],
    ['a version with spaces', { ...good, appVersion: '1.1 beta' }],
    ['a 33-character version', { ...good, appVersion: '1'.repeat(33) }],
    ['a fractional build', { ...good, build: 1.5 }],
    ['a negative build', { ...good, build: -1 }],
    ['a huge build', { ...good, build: 10_000_001 }],
    ['a string build', { ...good, build: '19' }],
  ])('refuses %s', (_name, body) => {
    expect(parseOpen(body, NOW)).toBeNull();
  });

  it('exports the install ID pattern the app and the rules share', () => {
    expect(INSTALL_ID_PATTERN).toBe('^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
  });
});

describe('dayIsOpenNow', () => {
  it('covers device-local days from UTC−12 to UTC+14', () => {
    expect(dayIsOpenNow('2026-10-17', NOW)).toBe(true);
    expect(dayIsOpenNow('2026-10-16', NOW)).toBe(true); // UTC−12 is still on the 16th until 12:00 UTC
    expect(dayIsOpenNow('2026-10-18', NOW)).toBe(true); // UTC+14 reaches the 18th at 10:00 UTC
    expect(dayIsOpenNow('2026-10-15', NOW)).toBe(false);
    expect(dayIsOpenNow('2026-10-19', NOW)).toBe(false);
  });
});

describe('recordGuestOpen', () => {
  afterEach(() => vi.unstubAllGlobals());

  const open = parseOpen(good, NOW)!;
  const name = guestDocName('p', open);
  const notFound = () => Response.json({ error: { status: 'NOT_FOUND' } }, { status: 404 });
  const exists = () => Response.json({ error: { status: 'ALREADY_EXISTS' } }, { status: 409 });
  const bodyOf = (fetchMock: ReturnType<typeof vi.fn>, call: number) =>
    JSON.parse(String((fetchMock.mock.calls[call] as unknown as [string, RequestInit])[1].body));

  const incrementWrite = {
    update: {
      name,
      fields: {
        platform: { stringValue: 'android' },
        appVersion: { stringValue: '1.1.0' },
        build: { integerValue: '19' },
      },
    },
    updateMask: { fieldPaths: ['platform', 'appVersion', 'build'] },
    updateTransforms: [
      { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'opens', increment: { integerValue: '1' } },
    ],
    currentDocument: { exists: true },
  };

  const createWrite = {
    update: {
      name,
      fields: {
        installId: { stringValue: ID },
        platform: { stringValue: 'android' },
        appVersion: { stringValue: '1.1.0' },
        build: { integerValue: '19' },
        opens: { integerValue: '1' },
      },
    },
    updateTransforms: [
      { fieldPath: 'firstOpenAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
    ],
    currentDocument: { exists: false },
  };

  it('names the doc under the day and the install', () => {
    expect(name).toBe('projects/p/databases/(default)/documents/daily_activity/2026-10-17/guests/' + ID);
  });

  it('a repeat open costs one commit: the increment, with no new-guest check', async () => {
    const fetchMock = vi.fn(async () => Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    const allowCreate = vi.fn(async () => true);
    expect(await recordGuestOpen({ projectId: 'p', accessToken: 't', open, allowCreate })).toBe('recorded');
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(bodyOf(fetchMock, 0).writes).toEqual([incrementWrite]);
    expect(allowCreate).not.toHaveBeenCalled();
  });

  it('a new guest: the increment finds no doc, then the doc is created with opens 1', async () => {
    const fetchMock = vi.fn().mockResolvedValueOnce(notFound()).mockResolvedValueOnce(Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    const allowCreate = vi.fn(async () => true);
    expect(await recordGuestOpen({ projectId: 'p', accessToken: 't', open, allowCreate })).toBe('recorded');
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(bodyOf(fetchMock, 1).writes).toEqual([createWrite]);
    expect(allowCreate).toHaveBeenCalledTimes(1);
  });

  it('creates nothing when the new-guest limit says no', async () => {
    const fetchMock = vi.fn().mockResolvedValueOnce(notFound());
    vi.stubGlobal('fetch', fetchMock);
    const result = await recordGuestOpen({ projectId: 'p', accessToken: 't', open, allowCreate: async () => false });
    expect(result).toBe('rate_limited');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('counts the open when the doc is created in between', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(notFound())
      .mockResolvedValueOnce(exists())
      .mockResolvedValueOnce(Response.json({}));
    vi.stubGlobal('fetch', fetchMock);
    expect(await recordGuestOpen({ projectId: 'p', accessToken: 't', open, allowCreate: async () => true })).toBe(
      'recorded',
    );
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(bodyOf(fetchMock, 2).writes).toEqual([incrementWrite]);
  });

  it('lets other failures through', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response('no', { status: 403 })));
    await expect(
      recordGuestOpen({ projectId: 'p', accessToken: 't', open, allowCreate: async () => true }),
    ).rejects.toThrow(/firestore_commit_failed:403/);
  });
});

describe('clientKey', () => {
  it.each([
    ['203.0.113.9', '203.0.113.9'],
    ['unknown', 'unknown'],
    ['2001:db8:1:2:3:4:5:6', '2001:db8:1:2::/64'],
    ['2001:0DB8:0001:0002:aaaa:bbbb:cccc:dddd', '2001:db8:1:2::/64'],
    ['2001:db8:1:2::1', '2001:db8:1:2::/64'],
    ['2001:db8::1', '2001:db8:0:0::/64'],
    ['::1', '0:0:0:0::/64'],
    ['::', '0:0:0:0::/64'],
    ['fe80::1%eth0', 'fe80:0:0:0::/64'],
    ['::ffff:203.0.113.9', '0:0:0:0::/64'],
  ])('%s -> %s', (ip, key) => {
    expect(clientKey(ip)).toBe(key);
  });

  it('puts every address of one /64 on one key', () => {
    expect(clientKey('2001:db8:1:2:1::1')).toBe(clientKey('2001:db8:1:2:ffff:eeee:dddd:cccc'));
    expect(clientKey('2001:db8:1:3::1')).not.toBe(clientKey('2001:db8:1:2::1'));
  });
});
