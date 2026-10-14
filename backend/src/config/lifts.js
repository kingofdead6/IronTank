/**
 * Ranked lifts and which library exercises count toward each.
 * Keys match `strengthStandards.json`. `bodyweight: true` lifts are ranked on
 * (bodyweight + added weight), where the logged set weight is the added load.
 */
export const RANKED_LIFTS = {
  bench_press: {
    name: 'Bench Press',
    bodyweight: false,
    sourceIds: ['Barbell_Bench_Press_-_Medium_Grip', 'Bench_Press_-_Powerlifting'],
    muscleGroups: { chest: 1, shoulders: 0.4, arms: 0.4 },
  },
  squat: {
    name: 'Squat',
    bodyweight: false,
    sourceIds: ['Barbell_Squat', 'Barbell_Full_Squat'],
    muscleGroups: { legs: 1, core: 0.3 },
  },
  deadlift: {
    name: 'Deadlift',
    bodyweight: false,
    sourceIds: ['Barbell_Deadlift', 'Sumo_Deadlift'],
    muscleGroups: { legs: 0.7, back: 1, core: 0.5 },
  },
  overhead_press: {
    name: 'Overhead Press',
    bodyweight: false,
    sourceIds: ['Standing_Military_Press'],
    muscleGroups: { shoulders: 1, arms: 0.4, core: 0.3 },
  },
  barbell_row: {
    name: 'Barbell Row',
    bodyweight: false,
    sourceIds: ['Bent_Over_Barbell_Row'],
    muscleGroups: { back: 1, arms: 0.4 },
  },
  pull_up: {
    name: 'Pull-Up',
    bodyweight: true,
    sourceIds: ['Pullups', 'Weighted_Pull_Ups'],
    muscleGroups: { back: 1, arms: 0.6 },
  },
  dips: {
    name: 'Dips',
    bodyweight: true,
    sourceIds: ['Dips_-_Chest_Version', 'Dips_-_Triceps_Version', 'Parallel_Bar_Dip'],
    muscleGroups: { chest: 0.7, arms: 1, shoulders: 0.3 },
  },
};

/** Reverse lookup: free-exercise-db id → lift key. */
export const LIFT_KEY_BY_SOURCE_ID = Object.fromEntries(
  Object.entries(RANKED_LIFTS).flatMap(([key, lift]) => lift.sourceIds.map((id) => [id, key])),
);

/** Coarse muscle groups used for distribution charts and group ranks. */
export const MUSCLE_GROUPS = {
  chest: ['chest'],
  back: ['lats', 'middle back', 'lower back', 'traps'],
  shoulders: ['shoulders', 'neck'],
  arms: ['biceps', 'triceps', 'forearms'],
  legs: ['quadriceps', 'hamstrings', 'glutes', 'calves', 'adductors', 'abductors'],
  core: ['abdominals'],
};

export const GROUP_BY_MUSCLE = Object.fromEntries(
  Object.entries(MUSCLE_GROUPS).flatMap(([group, muscles]) => muscles.map((m) => [m, group])),
);
