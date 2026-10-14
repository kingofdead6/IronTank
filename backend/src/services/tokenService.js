import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { RefreshToken } from '../models/RefreshToken.js';
import { AppError } from '../utils/AppError.js';

const DAY_MS = 24 * 60 * 60 * 1000;

export const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

export function signAccessToken(userId) {
  return jwt.sign({ sub: userId.toString(), typ: 'access' }, env.jwtSecret, {
    expiresIn: env.accessTokenTtl,
  });
}

export function verifyAccessToken(token) {
  try {
    const payload = jwt.verify(token, env.jwtSecret);
    if (payload.typ !== 'access') throw new Error('wrong token type');
    return payload;
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      throw AppError.unauthorized('Access token expired', 'TOKEN_EXPIRED');
    }
    throw AppError.unauthorized('Invalid access token', 'INVALID_TOKEN');
  }
}

/** Issues a new refresh token (optionally continuing an existing family) and persists its hash. */
export async function issueRefreshToken(userId, family = crypto.randomUUID()) {
  const token = jwt.sign(
    { sub: userId.toString(), typ: 'refresh', fam: family, jti: crypto.randomUUID() },
    env.jwtRefreshSecret,
    { expiresIn: `${env.refreshTokenTtlDays}d` },
  );
  const tokenHash = hashToken(token);
  await RefreshToken.create({
    userId,
    tokenHash,
    family,
    expiresAt: new Date(Date.now() + env.refreshTokenTtlDays * DAY_MS),
  });
  return { token, tokenHash };
}

/** Access + refresh pair for a freshly authenticated user. */
export async function issueTokenPair(userId, family) {
  const accessToken = signAccessToken(userId);
  const { token: refreshToken } = await issueRefreshToken(userId, family);
  return { accessToken, refreshToken };
}

/**
 * Rotates a refresh token: the presented token is revoked and replaced.
 * Presenting an already-revoked token is treated as theft and revokes the family.
 */
export async function rotateRefreshToken(presentedToken) {
  let payload;
  try {
    payload = jwt.verify(presentedToken, env.jwtRefreshSecret);
    if (payload.typ !== 'refresh') throw new Error('wrong token type');
  } catch {
    throw AppError.unauthorized('Invalid refresh token', 'INVALID_REFRESH_TOKEN');
  }

  const stored = await RefreshToken.findOne({ tokenHash: hashToken(presentedToken) });
  if (!stored) throw AppError.unauthorized('Invalid refresh token', 'INVALID_REFRESH_TOKEN');

  if (stored.revokedAt) {
    await RefreshToken.updateMany(
      { family: stored.family, revokedAt: null },
      { $set: { revokedAt: new Date() } },
    );
    throw AppError.unauthorized('Refresh token reuse detected; please sign in again', 'REFRESH_TOKEN_REUSED');
  }

  const accessToken = signAccessToken(stored.userId);
  const { token: refreshToken, tokenHash } = await issueRefreshToken(stored.userId, stored.family);
  stored.revokedAt = new Date();
  stored.replacedByHash = tokenHash;
  await stored.save();

  return { userId: stored.userId, accessToken, refreshToken };
}

/** Revokes a single refresh token (logout on this device). Unknown tokens are ignored. */
export async function revokeRefreshToken(presentedToken) {
  await RefreshToken.updateOne(
    { tokenHash: hashToken(presentedToken), revokedAt: null },
    { $set: { revokedAt: new Date() } },
  );
}

/** Revokes every refresh token of a user (logout everywhere). */
export async function revokeAllForUser(userId) {
  await RefreshToken.updateMany({ userId, revokedAt: null }, { $set: { revokedAt: new Date() } });
}
