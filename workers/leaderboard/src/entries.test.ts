import { describe, expect, it } from 'vitest';
import { planEntryWrite, planWeeklyWrite, toCommitWrite, type Submission } from './entries';

const identity = { displayName: 'Ada', photoUrl: null, avatarId: 'preset_01' };

const submission: Submission = {
  timeSeconds: 40,
  usedHints: false,
  hadMistakes: false,
  currentStreak: 3,
  identity,
};

const stored = (data: Record<string, unknown>) => ({ data, updateTime: 'T1' });

describe('planEntryWrite', () => {
  it('writes everything on a new entry', () => {
    const plan = planEntryWrite(null, submission);
    expect(plan.improved).toBe(true);
    expect(plan.touchUpdatedAt).toBe(true);
    expect(plan.precondition).toEqual({ exists: false });
    expect(plan.fields).toEqual({
      timeSeconds: 40,
      usedHints: false,
      hadMistakes: false,
      currentStreak: 3,
      displayName: 'Ada',
      photoUrl: null,
      avatarId: 'preset_01',
    });
  });

  it('only refreshes the streak and identity on a slower time', () => {
    const plan = planEntryWrite(stored({ timeSeconds: 30, usedHints: true }), submission);
    expect(plan.improved).toBe(false);
    expect(plan.touchUpdatedAt).toBe(false);
    expect(plan.precondition).toEqual({ updateTime: 'T1' });
    expect(plan.fields).toEqual({
      currentStreak: 3,
      displayName: 'Ada',
      photoUrl: null,
      avatarId: 'preset_01',
    });
  });

  it('keeps an equal time (ties go to whoever got there first)', () => {
    expect(planEntryWrite(stored({ timeSeconds: 40 }), submission).improved).toBe(false);
  });

  it('replaces the time and its flags on a faster time', () => {
    const plan = planEntryWrite(stored({ timeSeconds: 55 }), submission);
    expect(plan.improved).toBe(true);
    expect(plan.fields.timeSeconds).toBe(40);
    expect(plan.fields.usedHints).toBe(false);
  });

  it('leaves the identity alone when the app did not know it', () => {
    const plan = planEntryWrite(null, { ...submission, identity: null });
    expect(Object.keys(plan.fields).sort()).toEqual(
      ['currentStreak', 'hadMistakes', 'timeSeconds', 'usedHints'].sort(),
    );
  });
});

describe('planWeeklyWrite', () => {
  it('starts a week', () => {
    const plan = planWeeklyWrite(null, '2026-10-12', 61, identity);
    expect(plan.fields).toMatchObject({
      days: { '2026-10-12': 61 },
      daysCleared: 1,
      totalSeconds: 61,
      displayName: 'Ada',
    });
    expect(plan.touchUpdatedAt).toBe(true);
    expect(plan.precondition).toEqual({ exists: false });
  });

  it('adds a day and recomputes the totals', () => {
    const plan = planWeeklyWrite(
      stored({ days: { '2026-10-12': 61 }, daysCleared: 1, totalSeconds: 61 }),
      '2026-10-13',
      75,
      null,
    );
    expect(plan.fields).toEqual({
      days: { '2026-10-12': 61, '2026-10-13': 75 },
      daysCleared: 2,
      totalSeconds: 136,
    });
    expect(plan.touchUpdatedAt).toBe(true);
  });

  it('keeps the best time of a day and leaves updatedAt on a slower replay', () => {
    const existing = stored({ days: { '2026-10-12': 61 }, daysCleared: 1, totalSeconds: 61 });
    const slower = planWeeklyWrite(existing, '2026-10-12', 90, identity);
    expect(slower.fields.days).toEqual({ '2026-10-12': 61 });
    expect(slower.touchUpdatedAt).toBe(false);
    const faster = planWeeklyWrite(existing, '2026-10-12', 50, identity);
    expect(faster.fields).toMatchObject({ days: { '2026-10-12': 50 }, totalSeconds: 50 });
    expect(faster.touchUpdatedAt).toBe(true);
  });

  it('ignores junk in stored days and recomputes stale totals', () => {
    const plan = planWeeklyWrite(
      stored({ days: { '2026-10-12': 'x', '2026-10-13': 40 }, daysCleared: 9, totalSeconds: 1 }),
      '2026-10-14',
      20,
      null,
    );
    expect(plan.fields).toEqual({
      days: { '2026-10-13': 40, '2026-10-14': 20 },
      daysCleared: 2,
      totalSeconds: 60,
    });
  });
});

describe('toCommitWrite', () => {
  it('masks the planned fields and sets updatedAt to the commit time', () => {
    const write = toCommitWrite('doc', planEntryWrite(null, submission));
    expect(write.update.name).toBe('doc');
    expect(write.updateMask.fieldPaths.sort()).toEqual(
      Object.keys(planEntryWrite(null, submission).fields).sort(),
    );
    expect(write.updateTransforms).toEqual([
      { fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' },
    ]);
    expect(write.currentDocument).toEqual({ exists: false });
  });

  it('leaves updatedAt out when the time did not improve', () => {
    const write = toCommitWrite('doc', planEntryWrite(stored({ timeSeconds: 1 }), submission));
    expect(write.updateTransforms).toBeUndefined();
    expect(write.currentDocument).toEqual({ updateTime: 'T1' });
  });
});
