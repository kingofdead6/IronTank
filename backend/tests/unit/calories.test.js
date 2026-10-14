import { caloriesBurned, DEFAULT_BODYWEIGHT_KG, sessionCalories } from '../../src/services/calorieService.js';
import { ageFrom, calculateTargets, macrosFor, mifflinStJeor } from '../../src/services/tdeeService.js';

describe('caloriesBurned', () => {
  it('is MET × kg × hours', () => {
    expect(caloriesBurned({ metValue: 6, bodyweightKg: 80, seconds: 3600 })).toBe(480);
    expect(caloriesBurned({ metValue: 5, bodyweightKg: 70, seconds: 1800 })).toBe(175);
  });

  it('is zero for missing inputs', () => {
    expect(caloriesBurned({ metValue: 6, bodyweightKg: 80, seconds: 0 })).toBe(0);
    expect(caloriesBurned({ metValue: 0, bodyweightKg: 80, seconds: 60 })).toBe(0);
  });
});

describe('sessionCalories', () => {
  const meta = new Map([
    ['bench', { metValue: 6 }],
    ['curl', { metValue: 4 }],
  ]);
  const done = (n) => Array.from({ length: n }, () => ({ completed: true }));

  it('weights MET by completed sets and uses active time', () => {
    const session = {
      durationSec: 7200,
      activeDurationSec: 3600,
      exercises: [
        { exerciseId: 'bench', sets: [...done(3), { completed: false }] },
        { exerciseId: 'curl', sets: done(1) },
      ],
    };
    // MET = 6×0.75 + 4×0.25 = 5.5 → 5.5 × 80 × 1h
    expect(sessionCalories(session, meta, 80)).toEqual({ kcal: 440, usedDefaultBodyweight: false });
  });

  it('falls back to wall-clock duration and a default bodyweight', () => {
    const session = { durationSec: 3600, exercises: [{ exerciseId: 'bench', sets: done(2) }] };
    const result = sessionCalories(session, meta, null);
    expect(result).toEqual({ kcal: 6 * DEFAULT_BODYWEIGHT_KG, usedDefaultBodyweight: true });
  });

  it('uses a light MET when nothing was completed', () => {
    const session = { durationSec: 3600, exercises: [] };
    expect(sessionCalories(session, meta, 100).kcal).toBe(350);
  });
});

describe('TDEE (Mifflin-St Jeor)', () => {
  const now = new Date('2026-10-13T12:00:00Z');

  it('computes age with birthday handling', () => {
    expect(ageFrom('1996-10-13', now)).toBe(30);
    expect(ageFrom('1996-10-14', now)).toBe(29);
  });

  it('matches the published formula', () => {
    // male: 10×80 + 6.25×180 − 5×30 + 5 = 1780
    expect(mifflinStJeor({ sex: 'male', weightKg: 80, heightCm: 180, age: 30 })).toBe(1780);
    // female: 10×60 + 6.25×165 − 5×25 − 161 = 1345.25
    expect(mifflinStJeor({ sex: 'female', weightKg: 60, heightCm: 165, age: 25 })).toBeCloseTo(1345.25);
  });

  it('applies the activity factor and goal adjustments', () => {
    const r = calculateTargets(
      { sex: 'male', birthDate: '1996-01-01', heightCm: 180, bodyweightKg: 80, activityLevel: 'moderate', goal: 'cut' },
      now,
    );
    expect(r.bmr).toBe(1780);
    expect(r.tdee).toBe(Math.round(1780 * 1.55)); // 2759
    expect(r.targets.maintain.kcal).toBe(2759);
    expect(r.targets.cut.kcal).toBe(Math.round(1780 * 1.55 * 0.8));
    expect(r.targets.bulk.kcal).toBe(Math.round(1780 * 1.55 * 1.1));
    expect(r.recommendedKcal).toBe(r.targets.cut.kcal);
  });

  it('never recommends a cut below the safety floor', () => {
    const r = calculateTargets(
      { sex: 'female', birthDate: '1950-01-01', heightCm: 150, bodyweightKg: 45, activityLevel: 'sedentary' },
      now,
    );
    expect(r.targets.cut.kcal).toBe(1200);
  });

  it('reports missing profile fields', () => {
    expect(() => calculateTargets({ sex: 'male', heightCm: 180 })).toThrow(
      expect.objectContaining({ code: 'PROFILE_INCOMPLETE' }),
    );
  });

  it('splits macros sensibly', () => {
    const m = macrosFor(2500, 80, 'maintain');
    expect(m.proteinG).toBe(144);
    expect(m.fatG).toBe(Math.round((2500 * 0.25) / 9));
    expect(m.proteinG * 4 + m.fatG * 9 + m.carbsG * 4).toBeGreaterThan(2490);
  });
});
