/** Calendar dateId helpers for noun-pool prefetch (UTC arithmetic for a worldwide window). */

export function compactDateIdUtc(d = new Date()): string {
  const y = d.getUTCFullYear().toString().padStart(4, '0');
  const m = (d.getUTCMonth() + 1).toString().padStart(2, '0');
  const day = d.getUTCDate().toString().padStart(2, '0');
  return `${y}${m}${day}`;
}

export function addCompactDays(dateId: string, days: number): string {
  const y = Number(dateId.slice(0, 4));
  const m = Number(dateId.slice(4, 6));
  const d = Number(dateId.slice(6, 8));
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + days);
  return compactDateIdUtc(dt);
}

/** Prefetch window covering worldwide local midnights around now. */
export function prefetchDateIds(now = new Date()): string[] {
  const center = compactDateIdUtc(now);
  return [addCompactDays(center, -1), center, addCompactDays(center, 1)];
}
