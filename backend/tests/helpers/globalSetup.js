import { MongoMemoryServer } from 'mongodb-memory-server';

/** Starts one in-memory MongoDB for the whole test run. */
export default async function globalSetup() {
  const mongo = await MongoMemoryServer.create();
  globalThis.__MONGO__ = mongo;
  process.env.TEST_MONGO_URI = mongo.getUri();
}
