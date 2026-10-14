import { Router } from 'express';
import { z } from 'zod';
import * as ctrl from '../controllers/userController.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { ACTIVITY_LEVELS, GOALS, SEXES, UNITS } from '../models/User.js';
import { objectId, paginationQuery } from '../utils/zod.js';

const updateMeBody = z
  .object({
    username: z.string().trim().min(2).max(32),
    avatarUrl: z.string().url().max(2048).nullable(),
    sex: z.enum(SEXES),
    birthDate: z.coerce
      .date()
      .refine((d) => d < new Date(), 'Birth date must be in the past')
      .refine((d) => d > new Date('1900-01-01'), 'Birth date is too far in the past'),
    heightCm: z.number().min(100).max(250),
    bodyweightKg: z.number().min(20).max(400),
    unit: z.enum(UNITS),
    activityLevel: z.enum(ACTIVITY_LEVELS),
    goal: z.enum(GOALS),
    restTimerDefaultSec: z.number().int().min(15).max(600),
    onboardingComplete: z.boolean(),
  })
  .partial()
  .strict();

const bodyweightBody = z.object({
  kg: z.number().min(20).max(400),
  date: z.coerce.date().optional(),
});

const bodyweightQuery = paginationQuery.extend({
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
});

const router = Router();
router.use(requireAuth);

router.get('/me', ctrl.getMe);
router.patch('/me', validate({ body: updateMeBody }), ctrl.updateMe);
router.get('/me/bodyweight', validate({ query: bodyweightQuery }), ctrl.listBodyweight);
router.post('/me/bodyweight', validate({ body: bodyweightBody }), ctrl.addBodyweight);
router.delete(
  '/me/bodyweight/:entryId',
  validate({ params: z.object({ entryId: objectId }) }),
  ctrl.deleteBodyweight,
);

export default router;
