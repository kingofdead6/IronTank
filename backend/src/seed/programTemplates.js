/**
 * Built-in program templates. Exercises reference free-exercise-db ids
 * (`src`), resolved to Exercise documents at seed time.
 *
 * Shorthand: ex(src, sets, [minReps, maxReps], restSeconds, targetRPE?, notes?)
 */
const ex = (src, sets, [min, max], restSeconds, targetRPE = null, notes = '') => ({
  src,
  sets,
  repRange: { min, max },
  restSeconds,
  targetRPE,
  notes,
});

export const PROGRAM_TEMPLATES = [
  {
    templateKey: 'ppl',
    name: 'Push / Pull / Legs',
    description:
      'Classic hypertrophy split. Run the three days in order and repeat (3 or 6 sessions per week). ' +
      'Add weight once you hit the top of the rep range on every set.',
    weeks: 8,
    days: [
      {
        name: 'Push',
        exercises: [
          ex('Barbell_Bench_Press_-_Medium_Grip', 4, [6, 8], 150, 8),
          ex('Standing_Military_Press', 3, [8, 10], 120, 8),
          ex('Incline_Dumbbell_Press', 3, [8, 12], 90, 8),
          ex('Side_Lateral_Raise', 3, [12, 15], 60, 9),
          ex('Triceps_Pushdown', 3, [10, 12], 60, 9),
          ex('Dips_-_Triceps_Version', 2, [8, 12], 90, 8),
        ],
      },
      {
        name: 'Pull',
        exercises: [
          ex('Barbell_Deadlift', 3, [5, 5], 180, 8),
          ex('Pullups', 3, [6, 10], 120, 8),
          ex('Bent_Over_Barbell_Row', 3, [8, 10], 120, 8),
          ex('Seated_Cable_Rows', 3, [10, 12], 90, 8),
          ex('Face_Pull', 3, [15, 20], 60, 9),
          ex('Barbell_Curl', 3, [8, 12], 60, 9),
          ex('Hammer_Curls', 2, [10, 12], 60, 9),
        ],
      },
      {
        name: 'Legs',
        exercises: [
          ex('Barbell_Squat', 4, [6, 8], 180, 8),
          ex('Romanian_Deadlift', 3, [8, 10], 120, 8),
          ex('Leg_Press', 3, [10, 12], 120, 8),
          ex('Lying_Leg_Curls', 3, [10, 12], 60, 9),
          ex('Leg_Extensions', 3, [12, 15], 60, 9),
          ex('Standing_Calf_Raises', 4, [12, 15], 60, 9),
        ],
      },
    ],
  },
  {
    templateKey: 'upper-lower',
    name: 'Upper / Lower',
    description:
      'Four days per week alternating upper and lower body. Day A is heavier, day B uses more volume.',
    weeks: 8,
    days: [
      {
        name: 'Upper A',
        exercises: [
          ex('Barbell_Bench_Press_-_Medium_Grip', 4, [5, 6], 180, 8),
          ex('Bent_Over_Barbell_Row', 4, [6, 8], 150, 8),
          ex('Standing_Military_Press', 3, [6, 8], 120, 8),
          ex('Pullups', 3, [6, 10], 120, 8),
          ex('Barbell_Curl', 2, [8, 12], 60, 9),
          ex('Lying_Triceps_Press', 2, [8, 12], 60, 9),
        ],
      },
      {
        name: 'Lower A',
        exercises: [
          ex('Barbell_Squat', 4, [5, 6], 180, 8),
          ex('Romanian_Deadlift', 3, [6, 8], 150, 8),
          ex('Leg_Press', 3, [8, 10], 120, 8),
          ex('Standing_Calf_Raises', 4, [10, 12], 60, 9),
          ex('Hanging_Leg_Raise', 3, [10, 15], 60),
        ],
      },
      {
        name: 'Upper B',
        exercises: [
          ex('Incline_Dumbbell_Press', 4, [8, 12], 120, 8),
          ex('Wide-Grip_Lat_Pulldown', 4, [8, 12], 90, 8),
          ex('Seated_Dumbbell_Press', 3, [10, 12], 90, 8),
          ex('One-Arm_Dumbbell_Row', 3, [10, 12], 90, 8),
          ex('Side_Lateral_Raise', 3, [12, 15], 60, 9),
          ex('Hammer_Curls', 2, [10, 12], 60, 9),
          ex('Triceps_Pushdown', 2, [10, 12], 60, 9),
        ],
      },
      {
        name: 'Lower B',
        exercises: [
          ex('Barbell_Deadlift', 3, [4, 6], 180, 8),
          ex('Front_Barbell_Squat', 3, [8, 10], 150, 8),
          ex('Dumbbell_Lunges', 3, [10, 12], 90, 8, 'Reps per leg'),
          ex('Lying_Leg_Curls', 3, [10, 12], 60, 9),
          ex('Seated_Calf_Raise', 4, [12, 15], 60, 9),
        ],
      },
    ],
  },
  {
    templateKey: 'full-body-3x',
    name: 'Full Body 3x',
    description:
      'Three full-body sessions per week on non-consecutive days (e.g. Mon/Wed/Fri). Great for beginners and busy schedules.',
    weeks: 8,
    days: [
      {
        name: 'Full Body A',
        exercises: [
          ex('Barbell_Squat', 3, [6, 8], 150, 8),
          ex('Barbell_Bench_Press_-_Medium_Grip', 3, [6, 8], 150, 8),
          ex('Bent_Over_Barbell_Row', 3, [8, 10], 120, 8),
          ex('Side_Lateral_Raise', 2, [12, 15], 60, 9),
          ex('Plank', 3, [30, 60], 60, null, 'Reps = seconds held'),
        ],
      },
      {
        name: 'Full Body B',
        exercises: [
          ex('Barbell_Deadlift', 3, [5, 5], 180, 8),
          ex('Standing_Military_Press', 3, [6, 8], 120, 8),
          ex('Pullups', 3, [6, 10], 120, 8),
          ex('Leg_Press', 2, [10, 12], 90, 8),
          ex('Barbell_Curl', 2, [10, 12], 60, 9),
        ],
      },
      {
        name: 'Full Body C',
        exercises: [
          ex('Goblet_Squat', 3, [10, 12], 90, 8),
          ex('Incline_Dumbbell_Press', 3, [8, 12], 90, 8),
          ex('Seated_Cable_Rows', 3, [10, 12], 90, 8),
          ex('Romanian_Deadlift', 3, [8, 10], 120, 8),
          ex('Dips_-_Triceps_Version', 2, [8, 12], 90, 8),
        ],
      },
    ],
  },
  {
    templateKey: 'strength-5x5',
    name: '5x5 Strength',
    description:
      'Linear-progression strength program. Alternate workouts A and B three times per week. ' +
      'Add 2.5 kg to each lift (5 kg on deadlift) every session you complete all 5x5.',
    weeks: 12,
    days: [
      {
        name: 'Workout A',
        exercises: [
          ex('Barbell_Squat', 5, [5, 5], 180),
          ex('Barbell_Bench_Press_-_Medium_Grip', 5, [5, 5], 180),
          ex('Bent_Over_Barbell_Row', 5, [5, 5], 180),
        ],
      },
      {
        name: 'Workout B',
        exercises: [
          ex('Barbell_Squat', 5, [5, 5], 180),
          ex('Standing_Military_Press', 5, [5, 5], 180),
          ex('Barbell_Deadlift', 1, [5, 5], 240, null, 'One heavy top set after warm-ups'),
        ],
      },
    ],
  },
];
