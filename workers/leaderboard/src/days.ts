/**
 * Leaderboard days are the phone's local calendar day (`yyyy-MM-dd`), so one
 * day is open somewhere on Earth for 50 hours: from 00:00 at UTC+14 (10:00 UTC
 * the day before) to 24:00 at UTC-12 (12:00 UTC the day after). The rules use
 * the same window (`leaderboardDayIsLive` in firestore/firestore.rules).
 */

const HOUR_MS = 60 * 60 * 1000;

/** Hours before the day's UTC midnight that it opens (UTC+14). */
export const LIVE_FROM_HOURS_BEFORE = 14;

/** Hours after the day's UTC midnight that it closes (24 h + UTC-12). */
export const LIVE_UNTIL_HOURS_AFTER = 36;

export type DayParts = { year: number; month: number; day: number };

/** A real `yyyy-MM-dd` day, or null. */
export function parseDayId(dayId: unknown): DayParts | null {
  if (typeof dayId !== 'string') return null;
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dayId);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const back = new Date(Date.UTC(year, month - 1, day));
  if (
    back.getUTCFullYear() !== year ||
    back.getUTCMonth() !== month - 1 ||
    back.getUTCDate() !== day
  ) {
    return null;
  }
  return { year, month, day };
}

function utcMidnight(parts: DayParts): number {
  return Date.UTC(parts.year, parts.month - 1, parts.day);
}

/** `yyyy-MM-dd` → `YYYYMMDD`, the puzzle doc's date (`daily_YYYYMMDD`). */
export function compactDateId(dayId: string): string {
  return dayId.replace(/-/g, '');
}

/** Whether a board for [dayId] can take a time at [now]. */
export function isDayLive(dayId: string, now: Date): boolean {
  const parts = parseDayId(dayId);
  if (!parts) return false;
  const midnight = utcMidnight(parts);
  const t = now.getTime();
  return (
    t >= midnight - LIVE_FROM_HOURS_BEFORE * HOUR_MS &&
    t < midnight + LIVE_UNTIL_HOURS_AFTER * HOUR_MS
  );
}

/**
 * The ISO 8601 week (`yyyy-Www`) that holds [dayId]. Weeks start on Monday
 * and week 1 holds the year's first Thursday, so early January can belong to
 * the previous year's last week. `lib/domain/iso_week.dart` is the app's copy.
 */
export function isoWeekId(dayId: string): string {
  const parts = parseDayId(dayId);
  if (!parts) throw new Error(`Not a yyyy-MM-dd day: ${dayId}`);
  const date = new Date(utcMidnight(parts));
  const weekday = date.getUTCDay() || 7; // Monday 1 … Sunday 7
  // The Thursday of this week decides the week-year.
  date.setUTCDate(date.getUTCDate() + 4 - weekday);
  const weekYear = date.getUTCFullYear();
  const jan1 = Date.UTC(weekYear, 0, 1);
  const week = Math.floor((date.getTime() - jan1) / (24 * HOUR_MS) / 7) + 1;
  return `${weekYear}-W${String(week).padStart(2, '0')}`;
}
