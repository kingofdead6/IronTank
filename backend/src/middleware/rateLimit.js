import rateLimit from 'express-rate-limit';
import { env } from '../config/env.js';

const limitExceeded = (_req, res) =>
  res.status(429).json({
    error: { code: 'RATE_LIMITED', message: 'Too many requests, please try again later' },
  });

/** Tight limit for credential endpoints (login/register/forgot). */
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: env.isTest ? 1000 : 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: limitExceeded,
});

/** Looser limit for token refresh, which the app calls automatically. */
export const refreshLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: env.isTest ? 1000 : 120,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler: limitExceeded,
});
