/**
 * MET (metabolic equivalent) values used for calorie estimates.
 * Values are approximations from the Compendium of Physical Activities:
 *   resistance training, vigorous ≈ 6.0 · moderate ≈ 3.5–5.0
 *   calisthenics, moderate ≈ 3.8–4.5 · stretching ≈ 2.3 · cardio/plyo ≈ 7–8
 */

/** MET by the source dataset's (fine-grained) category, used when it is distinctive. */
export const MET_BY_SOURCE_CATEGORY = {
  stretching: 2.3,
  cardio: 7.0,
  plyometrics: 8.0,
  strongman: 7.0,
  'olympic weightlifting': 6.0,
  powerlifting: 6.0,
};

/** MET by equipment for general strength work. */
export const MET_BY_EQUIPMENT = {
  barbell: 6.0,
  'e-z curl bar': 5.0,
  dumbbell: 5.0,
  kettlebells: 6.0,
  'body only': 4.5,
  cable: 4.0,
  machine: 4.0,
  bands: 3.5,
  'medicine ball': 5.0,
  'exercise ball': 3.5,
  'foam roll': 2.0,
  other: 5.0,
  none: 4.0,
};

export const DEFAULT_MET = { strength: 5.0, cardio: 7.0, stretching: 2.3 };

/**
 * Picks a MET value for an exercise.
 * @param {{ category: string, sourceCategory?: string, equipment?: string }} ex
 */
export function metFor({ category, sourceCategory, equipment }) {
  if (sourceCategory && sourceCategory !== 'strength' && MET_BY_SOURCE_CATEGORY[sourceCategory]) {
    return MET_BY_SOURCE_CATEGORY[sourceCategory];
  }
  if (category === 'strength' && equipment && MET_BY_EQUIPMENT[equipment]) {
    return MET_BY_EQUIPMENT[equipment];
  }
  return DEFAULT_MET[category] ?? DEFAULT_MET.strength;
}
