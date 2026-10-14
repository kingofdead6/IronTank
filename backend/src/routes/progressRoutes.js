import { Router } from 'express';
import { z } from 'zod';
import * as prCtrl from '../controllers/prController.js';
import * as rankCtrl from '../controllers/rankController.js';
import * as statsCtrl from '../controllers/statsController.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { PR_TYPES } from '../models/PersonalRecord.js';
import { isValidTimeZone } from '../utils/dates.js';
import { objectId, paginationQuery } from '../utils/zod.js';

/** Routers for read-only progress data: /prs, /ranks and /stats. */

const tz = z.string().max(64).default('UTC').refine(isValidTimeZone, 'Unknown time zone');
const exerciseParams = z.object({ exerciseId: objectId });
const booleanish = z
  .enum(['true', 'false', '1', '0'])
  .transform((v) => v === 'true' || v === '1')
  .default('false');

export const prRoutes = Router();
prRoutes.use(requireAuth);
prRoutes.get(
  '/',
  validate({ query: paginationQuery.extend({ type: z.enum(PR_TYPES).optional(), includeBaselines: booleanish }) }),
  prCtrl.list,
);
prRoutes.get('/:exerciseId', validate({ params: exerciseParams, query: paginationQuery }), prCtrl.forExercise);

export const rankRoutes = Router();
rankRoutes.use(requireAuth);
rankRoutes.get('/', rankCtrl.get);

export const statsRoutes = Router();
statsRoutes.use(requireAuth);
statsRoutes.get(
  '/overview',
  validate({ query: z.object({ weeks: z.coerce.number().int().min(1).max(52).default(12), tz }) }),
  statsCtrl.getOverview,
);
statsRoutes.get(
  '/exercise/:exerciseId',
  validate({
    params: exerciseParams,
    query: paginationQuery.extend({ limit: z.coerce.number().int().min(1).max(100).default(50) }),
  }),
  statsCtrl.getExercise,
);
