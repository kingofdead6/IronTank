/**
 * Runs the API against a throwaway in-memory MongoDB (no Docker/Atlas needed).
 * Seeds exercises and program templates on start. Data is lost on exit.
 *
 *   npm run dev:memory
 */
import { MongoMemoryServer } from 'mongodb-memory-server';

const mongo = await MongoMemoryServer.create();
const uri = mongo.getUri('ironrank');
console.log(`In-memory MongoDB at ${uri}`);

const { start } = await import('../src/server.js');
await start(uri);

try {
  const { runSeed } = await import('../src/seed/index.js');
  await runSeed(['all'], { connect: false });
} catch (err) {
  console.warn(`Seed skipped: ${err.message}`);
}

process.once('exit', () => mongo.stop());
