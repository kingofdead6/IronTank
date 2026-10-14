import { readFileSync } from 'node:fs';
import { seedExercises } from '../../src/seed/seedExercises.js';
import { Exercise } from '../../src/models/Exercise.js';

/**
 * Real records from free-exercise-db: the seven ranked-lift basics, a few
 * cardio/stretching examples, and every exercise used by the program templates.
 */
export const sampleSource = JSON.parse(
  readFileSync(new URL('../fixtures/exercises.sample.json', import.meta.url), 'utf8'),
);

/** Seeds the sample library and returns a map of sourceId → Exercise doc. */
export async function seedSampleExercises() {
  await seedExercises({ source: sampleSource });
  const docs = await Exercise.find({ createdBy: null });
  return Object.fromEntries(docs.map((d) => [d.sourceId, d]));
}
