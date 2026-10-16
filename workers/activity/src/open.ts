import { commit, ContentionError, documentsBase, encodeFields, type CommitWrite } from './firestore';

export const PLATFORMS = ['ios', 'android', 'other'] as const;
export type Platform = (typeof PLATFORMS)[number];

/**
 * A lowercase UUID v4, as the app makes it. The same pattern is in
 * firestore/firestore.rules and lib/data/repositories/activity_install_id.dart;
 * test/firestore/activity_pins_test.dart keeps the three in step.
 */
export const INSTALL_ID_PATTERN = '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
const INSTALL_ID = new RegExp(INSTALL_ID_PATTERN);
const DAY_ID = /^\d{4}-\d{2}-\d{2}$/;
const APP_VERSION = /^[0-9A-Za-z.+-]{1,32}$/;
export const MAX_BUILD = 10_000_000;
const HOUR_MS = 60 * 60 * 1000;

export type GuestOpen = {
  installId: string;
  dayId: string;
  platform: Platform;
  appVersion: string;
  build: number;
};

function isRealDay(dayId: string): boolean {
  if (!DAY_ID.test(dayId)) return false;
  const ms = Date.parse(`${dayId}T00:00:00Z`);
  return !Number.isNaN(ms) && new Date(ms).toISOString().slice(0, 10) === dayId;
}

/**
 * Whether some device can be on [dayId] right now. Device clocks run from
 * UTC−12 to UTC+14, so a day is open from 14 h before its UTC midnight to
 * 36 h after (the leaderboard Worker's window).
 */
export function dayIsOpenNow(dayId: string, now: number): boolean {
  const midnight = Date.parse(`${dayId}T00:00:00Z`);
  return now >= midnight - 14 * HOUR_MS && now < midnight + 36 * HOUR_MS;
}

/** The open in [body], or null when any field is missing or out of bounds. */
export function parseOpen(body: unknown, now: number): GuestOpen | null {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return null;
  const { installId, dayId, platform, appVersion, build } = body as Record<string, unknown>;
  if (typeof installId !== 'string' || !INSTALL_ID.test(installId)) return null;
  if (typeof dayId !== 'string' || !isRealDay(dayId) || !dayIsOpenNow(dayId, now)) return null;
  if (typeof platform !== 'string' || !(PLATFORMS as readonly string[]).includes(platform)) return null;
  if (typeof appVersion !== 'string' || !APP_VERSION.test(appVersion)) return null;
  if (typeof build !== 'number' || !Number.isInteger(build) || build < 0 || build > MAX_BUILD) return null;
  return { installId, dayId, platform: platform as Platform, appVersion, build };
}

export function guestDocName(projectId: string, open: GuestOpen): string {
  return `${documentsBase(projectId)}/daily_activity/${open.dayId}/guests/${open.installId}`;
}

function createWrite(name: string, open: GuestOpen): CommitWrite {
  return {
    update: {
      name,
      fields: encodeFields({
        installId: open.installId,
        platform: open.platform,
        appVersion: open.appVersion,
        build: open.build,
        opens: 1,
      }),
    },
    updateTransforms: [
      { fieldPath: 'firstOpenAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
    ],
    currentDocument: { exists: false },
  };
}

function incrementWrite(name: string, open: GuestOpen): CommitWrite {
  return {
    update: {
      name,
      fields: encodeFields({ platform: open.platform, appVersion: open.appVersion, build: open.build }),
    },
    updateMask: { fieldPaths: ['platform', 'appVersion', 'build'] },
    updateTransforms: [
      { fieldPath: 'lastOpenAt', setToServerValue: 'REQUEST_TIME' },
      { fieldPath: 'opens', increment: { integerValue: '1' } },
    ],
    currentDocument: { exists: true },
  };
}

/**
 * The key the per-client limiters count on. An IPv4 address is its own key. An
 * IPv6 address maps to its /64 (the first four groups of the expanded
 * address), because one subscriber holds a whole /64 and can rotate through
 * it freely.
 */
export function clientKey(ip: string): string {
  const addr = ip.split('%')[0].toLowerCase();
  if (!addr.includes(':')) return ip;
  const groups = expandIpv6(addr);
  if (!groups) return addr;
  return `${groups.slice(0, 4).join(':')}::/64`;
}

/** The eight 16-bit groups of an IPv6 address as unpadded hex, or null if malformed. */
function expandIpv6(addr: string): string[] | null {
  let text = addr;
  const v4 = /(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(text);
  if (v4) {
    const [a, b, c, d] = v4.slice(1).map(Number);
    if ([a, b, c, d].some((n) => n > 255)) return null;
    text = text.slice(0, v4.index) + ((a << 8) | b).toString(16) + ':' + ((c << 8) | d).toString(16);
  }
  const halves = text.split('::');
  if (halves.length > 2) return null;
  const head = halves[0] ? halves[0].split(':') : [];
  const tail = halves.length === 2 && halves[1] ? halves[1].split(':') : [];
  const missing = 8 - head.length - tail.length;
  if (halves.length === 1 ? missing !== 0 : missing < 1) return null;
  const all = [...head, ...Array<string>(halves.length === 2 ? missing : 0).fill('0'), ...tail];
  const out: string[] = [];
  for (const g of all) {
    if (!/^[0-9a-f]{1,4}$/.test(g)) return null;
    out.push(parseInt(g, 16).toString(16));
  }
  return out;
}

export type RecordResult = 'recorded' | 'rate_limited';

/**
 * Counts one more open on the day's guest doc. A repeat open is one commit.
 * Only a doc that doesn't exist yet asks [allowCreate] (the new-guest limit);
 * when it says no, nothing is created.
 */
export async function recordGuestOpen(opts: {
  projectId: string;
  accessToken: string;
  open: GuestOpen;
  allowCreate: () => Promise<boolean>;
}): Promise<RecordResult> {
  const name = guestDocName(opts.projectId, opts.open);
  const send = (write: CommitWrite) =>
    commit({ projectId: opts.projectId, accessToken: opts.accessToken, writes: [write] });
  try {
    await send(incrementWrite(name, opts.open));
    return 'recorded';
  } catch (e) {
    if (!(e instanceof ContentionError)) throw e;
  }
  if (!(await opts.allowCreate())) return 'rate_limited';
  try {
    await send(createWrite(name, opts.open));
  } catch (e) {
    if (!(e instanceof ContentionError)) throw e;
    // Created in between (another request of the same install): count on it.
    await send(incrementWrite(name, opts.open));
  }
  return 'recorded';
}
