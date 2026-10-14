import { verifyAccessToken } from '../services/tokenService.js';
import { AppError } from '../utils/AppError.js';

/** Requires a valid `Authorization: Bearer <accessToken>` header; sets `req.userId`. */
export function requireAuth(req, _res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) return next(AppError.unauthorized());
  const payload = verifyAccessToken(token);
  req.userId = payload.sub;
  next();
}
