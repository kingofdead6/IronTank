/** Sets above this rep count are too inaccurate for a 1RM estimate and are ignored. */
export const MAX_E1RM_REPS = 12;

const round = (n, dp = 1) => Math.round(n * 10 ** dp) / 10 ** dp;

/**
 * Estimated one-rep max via the Epley formula: weight × (1 + reps / 30).
 * A single rep is the lift itself, so it returns the weight unchanged.
 *
 * @returns {number|null} e1RM in the input unit, or null when not estimable.
 */
export function epley(weight, reps) {
  if (!Number.isFinite(weight) || !Number.isFinite(reps)) return null;
  if (weight <= 0 || reps < 1 || reps > MAX_E1RM_REPS) return null;
  if (reps === 1) return round(weight);
  return round(weight * (1 + reps / 30));
}

/**
 * Load actually moved in a set. For bodyweight exercises the logged weight is
 * added load (negative = assistance), so the effective load includes bodyweight.
 */
export function effectiveLoad(weight, { isBodyweight }, bodyweightKg) {
  const w = Number(weight) || 0;
  if (!isBodyweight) return w;
  return (Number(bodyweightKg) || 0) + w;
}

/** e1RM of a set, using effective load. */
export function setE1rm(set, exercise, bodyweightKg) {
  return epley(effectiveLoad(set.weight, exercise, bodyweightKg), set.reps);
}
