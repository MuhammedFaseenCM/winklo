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

/** Creates the day's guest doc, or counts one more open on it when it exists. */
export async function recordGuestOpen(opts: {
  projectId: string;
  accessToken: string;
  open: GuestOpen;
}): Promise<void> {
  const name = guestDocName(opts.projectId, opts.open);
  try {
    await commit({ projectId: opts.projectId, accessToken: opts.accessToken, writes: [createWrite(name, opts.open)] });
  } catch (e) {
    if (!(e instanceof ContentionError)) throw e;
    await commit({ projectId: opts.projectId, accessToken: opts.accessToken, writes: [incrementWrite(name, opts.open)] });
  }
}
