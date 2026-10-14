import { computeStreaks, muscleDistribution } from '../../src/services/statsService.js';
import { addDays, localDay, weekStart } from '../../src/utils/dates.js';

describe('date helpers', () => {
  it('finds local calendar days across time zones', () => {
    const instant = '2026-10-13T23:30:00Z';
    expect(localDay(instant, 'UTC')).toBe('2026-10-13');
    expect(localDay(instant, 'Africa/Algiers')).toBe('2026-10-14'); // UTC+1
    expect(localDay(instant, 'America/New_York')).toBe('2026-10-13');
  });

  it('computes Monday week starts and day arithmetic', () => {
    expect(weekStart('2026-10-13')).toBe('2026-10-12'); // Tuesday → Monday
    expect(weekStart('2026-10-18')).toBe('2026-10-12'); // Sunday → previous Monday
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
  });
});

describe('computeStreaks', () => {
  const today = '2026-10-14'; // Wednesday

  it('counts consecutive days ending today or yesterday', () => {
    expect(computeStreaks(['2026-10-12', '2026-10-13', '2026-10-14'], today).days).toBe(3);
    expect(computeStreaks(['2026-10-12', '2026-10-13'], today).days).toBe(2); // not trained yet today
    expect(computeStreaks(['2026-10-11', '2026-10-12'], today).days).toBe(0);
  });

  it('counts consecutive training weeks, not breaking on the current week', () => {
    const days = ['2026-09-22', '2026-09-30', '2026-10-06']; // weeks of 9/21, 9/28, 10/5
    expect(computeStreaks(days, today).weeks).toBe(3);
    expect(computeStreaks([...days, '2026-10-13'], today).weeks).toBe(4);
    expect(computeStreaks(['2026-09-22'], today).weeks).toBe(0);
  });
});

describe('muscleDistribution', () => {
  it('credits primary muscles fully and secondary at half', () => {
    const meta = new Map([
      ['bench', { primaryMuscles: ['chest'], secondaryMuscles: ['shoulders', 'triceps'] }],
    ]);
    const sessions = [
      {
        exercises: [
          {
            exerciseId: 'bench',
            sets: [
              { completed: true, type: 'working' },
              { completed: true, type: 'working' },
              { completed: true, type: 'warmup' },
            ],
          },
        ],
      },
    ];
    const dist = Object.fromEntries(muscleDistribution(sessions, meta).map((d) => [d.group, d.sets]));
    expect(dist).toMatchObject({ chest: 2, shoulders: 0.5, arms: 0.5, legs: 0 });
  });
});
