import mongoose from 'mongoose';
import { env } from './env.js';

/**
 * Connects Mongoose to MongoDB. An explicit URI (used by tests and the
 * in-memory dev script) takes precedence over MONGO_URI from the environment.
 */
export async function connectDb(uri = env.mongoUri) {
  if (!uri) {
    throw new Error(
      'MONGO_URI is empty. Set it in backend/.env (local Docker or Atlas), ' +
        'or run `npm run dev:memory` to use a throwaway in-memory database.',
    );
  }
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);
  // Make sure declared indexes exist before serving traffic.
  await Promise.all(Object.values(mongoose.models).map((m) => m.syncIndexes()));
  return mongoose.connection;
}

export async function disconnectDb() {
  await mongoose.disconnect();
}
