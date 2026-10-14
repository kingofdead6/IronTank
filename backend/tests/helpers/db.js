import mongoose from 'mongoose';
import { connectDb } from '../../src/config/db.js';

/**
 * Each test file gets its own database on the shared in-memory server,
 * so files can't interfere with each other.
 */
export async function setupTestDb() {
  const base = process.env.TEST_MONGO_URI;
  const dbName = `test_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  await connectDb(`${base.replace(/\/$/, '')}/${dbName}`);
}

export async function clearDb() {
  const collections = await mongoose.connection.db.collections();
  await Promise.all(collections.map((c) => c.deleteMany({})));
}

export async function teardownTestDb() {
  await mongoose.connection.dropDatabase();
  await mongoose.disconnect();
}
