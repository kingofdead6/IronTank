import { AppError } from '../utils/AppError.js';

export const ACTIVITY_FACTORS = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

/** Calorie adjustment relative to maintenance for each goal. */
export const GOAL_ADJUSTMENT = { cut: -0.2, maintain: 0, bulk: 0.1 };

/** Floors below which a cut target is not recommended without supervision. */
const MIN_KCAL = { male: 1500, female: 1200 };

export function ageFrom(birthDate, now = new Date()) {
  const b = new Date(birthDate);
  let age = now.getFullYear() - b.getFullYear();
  const beforeBirthday =
    now.getMonth() < b.getMonth() || (now.getMonth() === b.getMonth() && now.getDate() < b.getDate());
  if (beforeBirthday) age -= 1;
  return age;
}

/** Mifflin-St Jeor basal metabolic rate (kcal/day). */
export function mifflinStJeor({ sex, weightKg, heightCm, age }) {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return sex === 'female' ? base - 161 : base + 5;
}

/** Protein / fat / carb split (grams) for a calorie target. */
export function macrosFor(kcal, weightKg, goal) {
  const proteinG = Math.round(weightKg * (goal === 'cut' ? 2.2 : 1.8));
  const fatG = Math.round((kcal * 0.25) / 9);
  const carbsG = Math.max(0, Math.round((kcal - proteinG * 4 - fatG * 9) / 4));
  return { proteinG, fatG, carbsG };
}

/**
 * Full TDEE breakdown for a user profile.
 * @throws {AppError} 422 PROFILE_INCOMPLETE when sex/birthDate/height/weight are missing.
 */
export function calculateTargets(
  { sex, birthDate, heightCm, bodyweightKg, activityLevel = 'moderate', goal = 'maintain' },
  now = new Date(),
) {
  const missing = Object.entries({ sex, birthDate, heightCm, bodyweightKg })
    .filter(([, v]) => v === null || v === undefined)
    .map(([k]) => k);
  if (missing.length) {
    throw new AppError(422, 'PROFILE_INCOMPLETE', 'Complete your profile to calculate a calorie target', {
      missing,
    });
  }

  const age = ageFrom(birthDate, now);
  const bmr = mifflinStJeor({ sex, weightKg: bodyweightKg, heightCm, age });
  const factor = ACTIVITY_FACTORS[activityLevel] ?? ACTIVITY_FACTORS.moderate;
  const tdee = bmr * factor;

  const targets = Object.fromEntries(
    Object.entries(GOAL_ADJUSTMENT).map(([g, adj]) => {
      const kcal = Math.round(Math.max(MIN_KCAL[sex], tdee * (1 + adj)));
      return [g, { kcal, macros: macrosFor(kcal, bodyweightKg, g) }];
    }),
  );

  return {
    age,
    bmr: Math.round(bmr),
    activityFactor: factor,
    tdee: Math.round(tdee),
    goal,
    targets,
    recommendedKcal: targets[goal].kcal,
  };
}
