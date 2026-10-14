import { pathToFileURL } from 'node:url';
import { createApp } from './app.js';
import { connectDb, disconnectDb } from './config/db.js';
import { env } from './config/env.js';

/**
 * Boots the API. `mongoUri` lets scripts (e.g. the in-memory dev server)
 * override MONGO_URI.
 */
export async function start(mongoUri) {
  await connectDb(mongoUri);
  const app = createApp();
  const server = app.listen(env.port, () => {
    console.log(`IronRank API listening on http://localhost:${env.port}`);
  });

  const shutdown = async (signal) => {
    console.log(`${signal} received, shutting down`);
    server.close(async () => {
      await disconnectDb();
      process.exit(0);
    });
  };
  process.once('SIGINT', () => shutdown('SIGINT'));
  process.once('SIGTERM', () => shutdown('SIGTERM'));
  return server;
}

// Run directly: `node src/server.js`
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  start().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}
