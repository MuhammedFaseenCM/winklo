/**
 * What one accepted submission writes, worked out from the docs as they were
 * read. Pure, so the rules of the boards are easy to test; `submit.ts` turns
 * the plans into one commit whose preconditions make sure nothing changed in
 * between.
 */

import type { CommitWrite, Precondition, StoredDoc } from './firestore';
import { encodeFields } from './firestore';
import type { Identity } from './identity';

export type Submission = {
  timeSeconds: number;
  usedHints: boolean;
  hadMistakes: boolean;
  currentStreak: number;
  /** Null when the app didn't know the player's profile: keep what's stored. */
  identity: Identity | null;
};

export type PlannedWrite = {
  /** Fields to set; any other stored field is left as it is. */
  fields: Record<string, unknown>;
  /** Whether `updatedAt` becomes this commit's time (it breaks ties). */
  touchUpdatedAt: boolean;
  precondition: Precondition;
  /** Whether the stored time (or the week's total) got better. */
  improved: boolean;
};

function preconditionFor(existing: StoredDoc | null): Precondition {
  return existing ? { updateTime: existing.updateTime } : { exists: false };
}

function identityFields(identity: Identity | null): Record<string, unknown> {
  if (!identity) return {};
  return {
    displayName: identity.displayName,
    photoUrl: identity.photoUrl,
    avatarId: identity.avatarId,
  };
}

function storedInt(value: unknown): number | null {
  return typeof value === 'number' && Number.isInteger(value) ? value : null;
}

/**
 * A daily or all-time entry: improve-only, like the app's direct write. The
 * time, its clean-run flags and `updatedAt` change only when the time gets
 * better; the streak and the identity are refreshed every time.
 */
export function planEntryWrite(
  existing: StoredDoc | null,
  submission: Submission,
): PlannedWrite {
  const stored = existing ? storedInt(existing.data.timeSeconds) : null;
  const improved = stored === null || submission.timeSeconds < stored;
  const fields: Record<string, unknown> = {
    currentStreak: submission.currentStreak,
    ...identityFields(submission.identity),
  };
  if (improved) {
    fields.timeSeconds = submission.timeSeconds;
    fields.usedHints = submission.usedHints;
    fields.hadMistakes = submission.hadMistakes;
  }
  return {
    fields,
    touchUpdatedAt: improved,
    precondition: preconditionFor(existing),
    improved,
  };
}

/**
 * A weekly entry: keeps each day's best time in `days`, and the totals the
 * board ranks by (`daysCleared` descending, then `totalSeconds`, then
 * `updatedAt`). `updatedAt` moves only when a day is added or improves.
 */
export function planWeeklyWrite(
  existing: StoredDoc | null,
  dayId: string,
  timeSeconds: number,
  identity: Identity | null,
): PlannedWrite {
  const days: Record<string, number> = {};
  const storedDays = existing?.data.days;
  if (storedDays && typeof storedDays === 'object' && !Array.isArray(storedDays)) {
    for (const [day, seconds] of Object.entries(storedDays)) {
      const value = storedInt(seconds);
      if (value !== null && value > 0) days[day] = value;
    }
  }
  const previous = days[dayId];
  const improved = previous === undefined || timeSeconds < previous;
  if (improved) days[dayId] = timeSeconds;
  const times = Object.values(days);
  return {
    fields: {
      days,
      daysCleared: times.length,
      totalSeconds: times.reduce((sum, t) => sum + t, 0),
      ...identityFields(identity),
    },
    touchUpdatedAt: improved || !existing,
    precondition: preconditionFor(existing),
    improved,
  };
}

export function toCommitWrite(name: string, plan: PlannedWrite): CommitWrite {
  const write: CommitWrite = {
    update: { name, fields: encodeFields(plan.fields) },
    updateMask: { fieldPaths: Object.keys(plan.fields) },
    currentDocument: plan.precondition,
  };
  if (plan.touchUpdatedAt) {
    write.updateTransforms = [
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ];
  }
  return write;
}
