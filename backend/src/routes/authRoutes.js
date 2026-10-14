import { Router } from 'express';
import { z } from 'zod';
import * as ctrl from '../controllers/authController.js';
import { validate } from '../middleware/validate.js';
import { authLimiter, refreshLimiter } from '../middleware/rateLimit.js';
import { verifyAccessToken } from '../services/tokenService.js';
import { email, password } from '../utils/zod.js';

const registerBody = z.object({
  email,
  password,
  username: z.string().trim().min(2).max(32),
});

const loginBody = z.object({ email, password: z.string().min(1).max(128) });

const refreshBody = z.object({ refreshToken: z.string().min(10) });

const logoutBody = z.object({
  refreshToken: z.string().min(10).optional(),
  allDevices: z.boolean().optional().default(false),
});

const forgotBody = z.object({ email });

/**
 * Logout works with just a refresh token; "all devices" additionally needs
 * a valid access token so we know whose sessions to revoke.
 */
function optionalAuth(req, _res, next) {
  const [scheme, token] = (req.get('authorization') || '').split(' ');
  if (scheme === 'Bearer' && token) {
    try {
      req.userId = verifyAccessToken(token).sub;
    } catch {
      // An expired access token is fine for a single-device logout.
    }
  }
  next();
}

const router = Router();

router.post('/register', authLimiter, validate({ body: registerBody }), ctrl.register);
router.post('/login', authLimiter, validate({ body: loginBody }), ctrl.login);
router.post('/refresh', refreshLimiter, validate({ body: refreshBody }), ctrl.refresh);
router.post('/logout', optionalAuth, validate({ body: logoutBody }), ctrl.logout);
router.post('/forgot-password', authLimiter, validate({ body: forgotBody }), ctrl.forgotPassword);

export default router;
