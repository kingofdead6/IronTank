import { Exercise } from '../models/Exercise.js';
import { Program } from '../models/Program.js';
import { PROGRAM_TEMPLATES } from './programTemplates.js';

/**
 * Upserts the built-in templates (matched by `templateKey`). Requires the
 * exercise library to be seeded first. Users' own copies are never touched.
 */
export async function seedPrograms(templates = PROGRAM_TEMPLATES) {
  const sourceIds = [...new Set(templates.flatMap((t) => t.days.flatMap((d) => d.exercises.map((e) => e.src))))];
  const exercises = await Exercise.find({ sourceId: { $in: sourceIds }, createdBy: null }).select('_id sourceId');
  const idBySource = new Map(exercises.map((e) => [e.sourceId, e._id]));

  const missing = sourceIds.filter((s) => !idBySource.has(s));
  if (missing.length) {
    throw new Error(`Seed exercises first; missing: ${missing.join(', ')}`);
  }

  let upserted = 0;
  for (const t of templates) {
    const days = t.days.map((d) => ({
      name: d.name,
      exercises: d.exercises.map(({ src, ...rest }) => ({ exerciseId: idBySource.get(src), ...rest })),
    }));
    await Program.findOneAndUpdate(
      { templateKey: t.templateKey, isTemplate: true },
      {
        $set: { name: t.name, description: t.description, weeks: t.weeks, days },
        $setOnInsert: { templateKey: t.templateKey, isTemplate: true, userId: null, isActive: false },
      },
      { upsert: true, runValidators: true },
    );
    upserted += 1;
  }
  return { total: upserted };
}
