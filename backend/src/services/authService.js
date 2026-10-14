import bcrypt from 'bcrypt';
import { env } from '../config/env.js';
import { User } from '../models/User.js';
import { AppError } from '../utils/AppError.js';
import {
  issueTokenPair,
  revokeAllForUser,
  revokeRefreshToken,
  rotateRefreshToken,
} from './tokenService.js';

export async function register({ email, password, username }) {
  const existing = await User.exists({ email: email.toLowerCase() });
  if (existing) throw AppError.conflict('An account with this email already exists', 'EMAIL_TAKEN');

  const passwordHash = await bcrypt.hash(password, env.bcryptRounds);
  const user = await User.create({ email, passwordHash, username });
  const tokens = await issueTokenPair(user._id);
  return { user, ...tokens };
}

export async function login({ email, password }) {
  const user = await User.findOne({ email: email.toLowerCase() }).select('+passwordHash');
  // Same error for unknown email and wrong password to avoid account enumeration.
  const ok = user ? await bcrypt.compare(password, user.passwordHash) : false;
  if (!ok) throw AppError.unauthorized('Invalid email or password', 'INVALID_CREDENTIALS');

  const tokens = await issueTokenPair(user._id);
  return { user, ...tokens };
}

export async function refresh(refreshToken) {
  const { userId, accessToken, refreshToken: next } = await rotateRefreshToken(refreshToken);
  const user = await User.findById(userId);
  if (!user) throw AppError.unauthorized('Account no longer exists', 'INVALID_REFRESH_TOKEN');
  return { user, accessToken, refreshToken: next };
}

export async function logout({ refreshToken, userId, allDevices }) {
  if (allDevices && userId) {
    await revokeAllForUser(userId);
  } else if (refreshToken) {
    await revokeRefreshToken(refreshToken);
  }
}

/**
 * Stub: a real implementation would create a single-use reset token and email it.
 * We always respond the same way so the endpoint can't be used to probe for accounts.
 */
export async function forgotPassword({ email }) {
  await User.exists({ email: email.toLowerCase() });
  return { message: 'If an account exists for this email, a reset link has been sent.' };
}
