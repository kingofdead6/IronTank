import { LIFT_KEY_BY_SOURCE_ID } from '../config/lifts.js';
import { metFor } from '../config/metTable.js';
import { CATEGORIES, EQUIPMENT, Exercise, LEVELS, MUSCLES } from '../models/Exercise.js';
import { AppError } from '../utils/AppError.js';
import { paginate } from '../utils/pagination.js';

export const FREE_EXERCISE_DB_JSON =
  'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
export const FREE_EXERCISE_DB_IMAGES =
  'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';

/** Collapses free-exercise-db's seven categories into the app's three. */
const CATEGORY_MAP = {
  strength: 'strength',
  powerlifting: 'strength',
  'olympic weightlifting': 'strength',
  strongman: 'strength',
  plyometrics: 'cardio',
  cardio: 'cardio',
  stretching: 'stretching',
};

export function slugify(value) {
  return value
    .toString()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * Maps one free-exercise-db record to the Exercise model shape.
 * Pure function so it can be unit tested without a database.
 */
export function mapSourceExercise(src) {
  const category = CATEGORY_MAP[src.category] ?? 'strength';
  const equipment = EQUIPMENT.includes(src.equipment) ? src.equipment : src.equipment ? 'other' : 'none';
  const liftKey = LIFT_KEY_BY_SOURCE_ID[src.id] ?? null;
  const keepMuscles = (list) => (list ?? []).filter((m) => MUSCLES.includes(m));

  return {
    name: src.name.trim(),
    slug: slugify(src.id),
    sourceId: src.id,
    primaryMuscles: keepMuscles(src.primaryMuscles),
    secondaryMuscles: keepMuscles(src.secondaryMuscles),
    equipment,
    category,
    sourceCategory: src.category ?? null,
    force: ['push', 'pull', 'static'].includes(src.force) ? src.force : null,
    mechanic: ['compound', 'isolation'].includes(src.mechanic) ? src.mechanic : null,
    level: LEVELS.includes(src.level) ? src.level : 'beginner',
    instructions: (src.instructions ?? []).map((s) => s.trim()).filter(Boolean),
    images: (src.images ?? []).map((p) => FREE_EXERCISE_DB_IMAGES + p.split('/').map(encodeURIComponent).join('/')),
    metValue: metFor({ category, sourceCategory: src.category, equipment }),
    isBodyweight: equipment === 'body only',
    liftKey,
    isCustom: false,
    createdBy: null,
  };
}

/** Exercises a user may see: the global library plus their own custom ones. */
const visibleTo = (userId) => ({ $or: [{ createdBy: null }, { createdBy: userId }] });

export async function listExercises(userId, { q, muscle, equipment, category, level, scope, page, limit }) {
  const and = [];
  if (scope === 'custom') and.push({ createdBy: userId });
  else if (scope === 'global') and.push({ createdBy: null });
  else and.push(visibleTo(userId));

  if (q) and.push({ name: { $regex: escapeRegex(q.trim()), $options: 'i' } });
  if (muscle?.length) {
    and.push({ $or: [{ primaryMuscles: { $in: muscle } }, { secondaryMuscles: { $in: muscle } }] });
  }
  if (equipment?.length) and.push({ equipment: { $in: equipment } });
  if (category?.length) and.push({ category: { $in: category } });
  if (level?.length) and.push({ level: { $in: level } });

  return paginate(Exercise, { $and: and }, { page, limit, sort: { name: 1, _id: 1 } });
}

export async function getExercise(userId, id) {
  const exercise = await Exercise.findOne({ _id: id, ...visibleTo(userId) });
  if (!exercise) throw AppError.notFound('Exercise');
  return exercise;
}

export function filterOptions() {
  return { muscles: MUSCLES, equipment: EQUIPMENT, categories: CATEGORIES, levels: LEVELS };
}

export async function createCustomExercise(userId, data) {
  const category = data.category ?? 'strength';
  const equipment = data.equipment ?? 'none';
  const base = slugify(data.name) || 'exercise';
  // Keep slugs unique per user: "my-curl", "my-curl-2", ...
  let slug = base;
  for (let n = 2; await Exercise.exists({ slug, createdBy: userId }); n += 1) slug = `${base}-${n}`;

  return Exercise.create({
    ...data,
    slug,
    category,
    equipment,
    metValue: data.metValue ?? metFor({ category, equipment }),
    isBodyweight: data.isBodyweight ?? equipment === 'body only',
    liftKey: null,
    isCustom: true,
    createdBy: userId,
  });
}

async function loadOwned(userId, id) {
  const exercise = await Exercise.findById(id);
  if (!exercise) throw AppError.notFound('Exercise');
  if (!exercise.createdBy || exercise.createdBy.toString() !== userId.toString()) {
    // Global exercises are read-only; other users' customs are invisible.
    if (!exercise.createdBy) throw AppError.forbidden('Library exercises cannot be modified');
    throw AppError.notFound('Exercise');
  }
  return exercise;
}

export async function updateCustomExercise(userId, id, data) {
  const exercise = await loadOwned(userId, id);
  exercise.set(data);
  if (data.category || data.equipment) {
    if (data.metValue === undefined) exercise.metValue = metFor(exercise);
  }
  await exercise.save();
  return exercise;
}

export async function deleteCustomExercise(userId, id) {
  const exercise = await loadOwned(userId, id);
  await exercise.deleteOne();
}
