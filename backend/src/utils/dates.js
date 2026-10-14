/**
 * Calendar-day helpers. Days are represented as 'YYYY-MM-DD' strings in the
 * user's time zone so "today", weeks and streaks match the user's local calendar.
 */

const DAY_MS = 24 * 60 * 60 * 1000;
const formatters = new Map();

export function isValidTimeZone(tz) {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

/** Local calendar day of an instant in a time zone, e.g. '2026-10-13'. */
export function localDay(date, tz = 'UTC') {
  if (!formatters.has(tz)) {
    formatters.set(
      tz,
      new Intl.DateTimeFormat('en-CA', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit' }),
    );
  }
  return formatters.get(tz).format(new Date(date));
}

/** Pure calendar arithmetic on 'YYYY-MM-DD' strings (UTC-based, no DST issues). */
export function addDays(day, n) {
  const d = new Date(`${day}T00:00:00Z`);
  return new Date(d.getTime() + n * DAY_MS).toISOString().slice(0, 10);
}

/** Monday of the ISO week containing `day`. */
export function weekStart(day) {
  const dow = new Date(`${day}T00:00:00Z`).getUTCDay(); // 0 = Sunday
  return addDays(day, -((dow + 6) % 7));
}

export function daysBetween(a, b) {
  return Math.round((new Date(`${b}T00:00:00Z`) - new Date(`${a}T00:00:00Z`)) / DAY_MS);
}

/**
 * A UTC window that safely contains a whole local day (±14h offsets), for
 * coarse DB filtering before exact local-day matching in JS.
 */
export function utcWindowForDays(fromDay, toDay) {
  return {
    $gte: new Date(new Date(`${fromDay}T00:00:00Z`).getTime() - 14 * 3600 * 1000),
    $lt: new Date(new Date(`${toDay}T00:00:00Z`).getTime() + DAY_MS + 14 * 3600 * 1000),
  };
}
