import { Router } from 'express';
import { z } from 'zod';
import * as ctrl from '../controllers/programController.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { idParams, objectId, paginationQuery } from '../utils/zod.js';

const programExercise = z
  .object({
    exerciseId: objectId,
    sets: z.number().int().min(1).max(20).default(3),
    repRange: z
      .object({ min: z.number().int().min(1).max(100), max: z.number().int().min(1).max(100) })
      .default({ min: 8, max: 12 }),
    targetRPE: z.number().min(1).max(10).nullable().default(null),
    restSeconds: z.number().int().min(0).max(900).default(90),
    notes: z.string().max(500).default(''),
  })
  .strict();

const programDay = z
  .object({
    name: z.string().trim().min(1).max(60),
    exercises: z.array(programExercise).max(30).default([]),
  })
  .strict();

const createBody = z
  .object({
    name: z.string().trim().min(1).max(80),
    description: z.string().max(1000).default(''),
    weeks: z.number().int().min(1).max(52).default(8),
    days: z.array(programDay).max(14).default([]),
  })
  .strict();

const updateBody = z
  .object({
    name: z.string().trim().min(1).max(80),
    description: z.string().max(1000),
    weeks: z.number().int().min(1).max(52),
    days: z.array(programDay).max(14),
  })
  .partial()
  .strict();

const listQuery = paginationQuery.extend({ scope: z.enum(['all', 'mine', 'templates']).default('all') });

const router = Router();
router.use(requireAuth);

router.get('/', validate({ query: listQuery }), ctrl.list);
router.get('/active', ctrl.active);
router.delete('/active', ctrl.deactivate);
router.post('/', validate({ body: createBody }), ctrl.create);
router.get('/:id', validate({ params: idParams }), ctrl.getOne);
router.patch('/:id', validate({ params: idParams, body: updateBody }), ctrl.update);
router.delete('/:id', validate({ params: idParams }), ctrl.remove);
router.post('/:id/clone', validate({ params: idParams }), ctrl.clone);
router.post('/:id/activate', validate({ params: idParams }), ctrl.activate);

export default router;
