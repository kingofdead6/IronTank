import { readFile } from 'node:fs/promises';
import { Exercise } from '../models/Exercise.js';
import { FREE_EXERCISE_DB_JSON, mapSourceExercise } from '../services/exerciseService.js';

/**
 * Loads the free-exercise-db dataset (public domain, github.com/yuhonas/free-exercise-db)
 * either from a local JSON file or by downloading it.
 */
export async function loadSourceExercises({ file } = {}) {
  if (file) return JSON.parse(await readFile(file, 'utf8'));

  const res = await fetch(FREE_EXERCISE_DB_JSON);
  if (!res.ok) throw new Error(`Failed to download exercises: HTTP ${res.status}`);
  return res.json();
}

/**
 * Upserts the global exercise library. Idempotent: re-running updates existing
 * exercises in place (matched by slug) and never touches users' custom exercises,
 * so existing workout references stay valid.
 *
 * @returns {Promise<{ total: number, inserted: number, updated: number }>}
 */
export async function seedExercises({ file, source } = {}) {
  const raw = source ?? (await loadSourceExercises({ file }));
  const docs = raw.filter((e) => e?.id && e?.name).map(mapSourceExercise);

  const ops = docs.map((doc) => ({
    updateOne: {
      filter: { slug: doc.slug, createdBy: null },
      update: { $set: doc },
      upsert: true,
    },
  }));

  const result = await Exercise.bulkWrite(ops, { ordered: false });
  return { total: docs.length, inserted: result.upsertedCount, updated: result.modifiedCount };
}
