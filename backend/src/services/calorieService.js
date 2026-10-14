/** Used when the user hasn't entered a bodyweight yet. Results are flagged as such. */
export const DEFAULT_BODYWEIGHT_KG = 75;

/** kcal = MET × bodyweight (kg) × hours. */
export function caloriesBurned({ metValue, bodyweightKg, seconds }) {
  if (!(metValue > 0) || !(bodyweightKg > 0) || !(seconds > 0)) return 0;
  return metValue * bodyweightKg * (seconds / 3600);
}

/**
 * Estimates calories for a whole session from its *active* time.
 * Time is split across exercises in proportion to their completed sets, so a
 * session of mostly barbell work uses mostly the barbell MET.
 *
 * @param {object} session  { activeDurationSec?, durationSec, exercises: [{ exerciseId, sets: [{ completed }] }] }
 * @param {Map<string, {metValue:number}>} exercisesById
 * @param {number|null} bodyweightKg
 * @returns {{ kcal: number, usedDefaultBodyweight: boolean }}
 */
export function sessionCalories(session, exercisesById, bodyweightKg) {
  const seconds = session.activeDurationSec || session.durationSec || 0;
  const usedDefaultBodyweight = !(bodyweightKg > 0);
  const bw = usedDefaultBodyweight ? DEFAULT_BODYWEIGHT_KG : bodyweightKg;

  const weighted = [];
  for (const ex of session.exercises ?? []) {
    const meta = exercisesById.get(ex.exerciseId.toString());
    const done = (ex.sets ?? []).filter((s) => s.completed).length;
    if (meta && done > 0) weighted.push({ met: meta.metValue, sets: done });
  }

  const totalSets = weighted.reduce((sum, w) => sum + w.sets, 0);
  // No completed sets: fall back to light general training for the time spent.
  const met = totalSets
    ? weighted.reduce((sum, w) => sum + w.met * (w.sets / totalSets), 0)
    : 3.5;

  return { kcal: Math.round(caloriesBurned({ metValue: met, bodyweightKg: bw, seconds })), usedDefaultBodyweight };
}
