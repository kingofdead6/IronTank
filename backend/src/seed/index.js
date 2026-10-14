/**
 * Seed entry point.
 *
 *   npm run seed                     # everything
 *   npm run seed:exercises           # exercise library only
 *   node src/seed/index.js exercises --file ./exercises.json   # offline copy of the dataset
 */
import { pathToFileURL } from 'node:url';
import { connectDb, disconnectDb } from '../config/db.js';
import { seedExercises } from './seedExercises.js';
import { seedPrograms } from './seedPrograms.js';

const TASKS = {
  exercises: async (opts) => {
    const r = await seedExercises(opts);
    console.log(`Exercises: ${r.total} processed (${r.inserted} new, ${r.updated} updated)`);
  },
  programs: async () => {
    const r = await seedPrograms();
    console.log(`Program templates: ${r.total} upserted`);
  },
};

/**
 * @param {string[]} targets  e.g. ['all'] or ['exercises']
 * @param {{ connect?: boolean, file?: string }} opts
 */
export async function runSeed(targets = ['all'], { connect = true, file } = {}) {
  const names = targets.includes('all') || targets.length === 0 ? Object.keys(TASKS) : targets;
  const unknown = names.filter((n) => !TASKS[n]);
  if (unknown.length) throw new Error(`Unknown seed target(s): ${unknown.join(', ')}`);

  if (connect) await connectDb();
  try {
    // Order matters: programs reference exercises.
    for (const name of Object.keys(TASKS)) {
      if (names.includes(name)) await TASKS[name]({ file });
    }
  } finally {
    if (connect) await disconnectDb();
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = process.argv.slice(2);
  let file;
  const targets = [];
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--file') file = args[(i += 1)];
    else targets.push(args[i]);
  }

  runSeed(targets.length ? targets : ['all'], { file })
    .then(() => console.log('Seed complete'))
    .catch((err) => {
      console.error(`Seed failed: ${err.message}`);
      process.exit(1);
    });
}
