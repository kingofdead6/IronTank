import 'dotenv/config';

/**
 * Centralised, validated access to environment variables.
 * Fails fast at boot when a required secret is missing (except in tests,
 * where the test harness injects its own values).
 */
const isTest = process.env.NODE_ENV === 'test';

function required(name, fallbackForTest) {
  const value = process.env[name];
  if (value && value.trim() !== '') return value;
  if (isTest && fallbackForTest !== undefined) return fallbackForTest;
  throw new Error(`Missing required environment variable: ${name}`);
}

export const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  isTest,
  isProd: process.env.NODE_ENV === 'production',
  port: Number(process.env.PORT) || 4000,
  // MONGO_URI is resolved lazily in db.js so tests / dev:memory can inject one.
  mongoUri: process.env.MONGO_URI || '',
  jwtSecret: required('JWT_SECRET', 'test-access-secret'),
  jwtRefreshSecret: required('JWT_REFRESH_SECRET', 'test-refresh-secret'),
  accessTokenTtl: process.env.ACCESS_TOKEN_TTL || '15m',
  refreshTokenTtlDays: Number(process.env.REFRESH_TOKEN_TTL_DAYS) || 30,
  corsOrigin: process.env.CORS_ORIGIN || '*',
  bcryptRounds: isTest ? 4 : 12,
};
