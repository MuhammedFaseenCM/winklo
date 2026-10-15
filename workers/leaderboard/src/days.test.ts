import { describe, expect, it } from 'vitest';
import { compactDateId, isDayLive, isoWeekId, parseDayId } from './days';

describe('parseDayId', () => {
  it('accepts a real yyyy-MM-dd day', () => {
    expect(parseDayId('2026-10-15')).toEqual({ year: 2026, month: 10, day: 15 });
  });

  it('refuses other shapes and impossible dates', () => {
    for (const bad of ['2026-02-30', '2026-13-01', '20261015', '2026-1-05', '', 'x']) {
      expect(parseDayId(bad)).toBeNull();
    }
    expect(parseDayId(42)).toBeNull();
  });
});

describe('compactDateId', () => {
  it('drops the dashes', () => {
    expect(compactDateId('2026-10-05')).toBe('20261005');
  });
});

describe('isDayLive', () => {
  const day = '2026-10-15';
  it('opens at 10:00 UTC on the day before', () => {
    expect(isDayLive(day, new Date('2026-10-14T09:59:59.999Z'))).toBe(false);
    expect(isDayLive(day, new Date('2026-10-14T10:00:00.000Z'))).toBe(true);
  });

  it('closes at 12:00 UTC on the day after', () => {
    expect(isDayLive(day, new Date('2026-10-16T11:59:59.999Z'))).toBe(true);
    expect(isDayLive(day, new Date('2026-10-16T12:00:00.000Z'))).toBe(false);
  });

  it('refuses a day that is not real', () => {
    expect(isDayLive('2026-02-30', new Date('2026-03-01T12:00:00Z'))).toBe(false);
  });
});

describe('isoWeekId', () => {
  it.each([
    ['2026-01-01', '2026-W01'],
    ['2026-10-12', '2026-W42'],
    ['2026-10-15', '2026-W42'],
    ['2026-10-18', '2026-W42'],
    ['2026-10-19', '2026-W43'],
    ['2027-01-01', '2026-W53'],
    ['2024-12-30', '2025-W01'],
    ['2021-01-03', '2020-W53'],
  ])('%s is in %s', (dayId, weekId) => {
    expect(isoWeekId(dayId)).toBe(weekId);
  });
});
