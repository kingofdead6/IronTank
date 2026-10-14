import { Router } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { GOALS } from '../models/User.js';
import * as ctrl from '../controllers/calorieController.js';
import { isValidTimeZone } from '../utils/dates.js';
import { isoDay, objectId, paginationQuery } from '../utils/zod.js';

const tz = z.string().max(64).default('UTC').refine(isValidTimeZone, 'Unknown time zone');

/** GET /calories?date=YYYY-MM-DD → one day; GET /calories?from&to → paginated days. */
const getQuery = paginationQuery.extend({
  date: isoDay.optional(),
  from: isoDay.optional(),
  to: isoDay.optional(),
  tz,
});

const entryBody = z
  .object({
    date: isoDay,
    tz,
    name: z.string().trim().min(1).max(120),
    kcal: z.number().min(0).max(10000),
    protein: z.number().min(0).max(1000).default(0),
    carbs: z.number().min(0).max(2000).default(0),
    fat: z.number().min(0).max(1000).default(0),
  })
  .strict();

const targetBody = z
  .object({
    targetKcal: z.number().int().min(800).max(10000).nullable().optional(),
    goal: z.enum(GOALS).optional(),
    date: isoDay.optional(),
  })
  .strict()
  .refine((b) => b.targetKcal !== undefined || b.goal, 'Provide targetKcal and/or goal');

const router = Router();
router.use(requireAuth);

router.get('/', validate({ query: getQuery }), ctrl.get);
router.post('/entries', validate({ body: entryBody }), ctrl.addEntry);
router.delete('/entries/:entryId', validate({ params: z.object({ entryId: objectId }) }), ctrl.deleteEntry);
router.get('/target', ctrl.getTarget);
router.put('/target', validate({ body: targetBody }), ctrl.setTarget);

export default router;
