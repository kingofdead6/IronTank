import { Router } from 'express';
import { z } from 'zod';
import * as ctrl from '../controllers/workoutController.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { SET_TYPES } from '../models/WorkoutSession.js';
import { idParams, objectId, paginationQuery } from '../utils/zod.js';

const setSchema = z
  .object({
    weight: z.number().min(-300).max(1000).default(0),
    reps: z.number().int().min(0).max(1000).default(0),
    rpe: z.number().min(1).max(10).multipleOf(0.5).nullable().default(null),
    type: z.enum(SET_TYPES).default('working'),
    completed: z.boolean().default(false),
    restTaken: z.number().int().min(0).max(7200).nullable().default(null),
    completedAt: z.coerce.date().nullable().default(null),
  })
  .strict();

const sessionExercise = z
  .object({
    exerciseId: objectId,
    restSeconds: z.number().int().min(0).max(900).nullable().default(null),
    notes: z.string().max(1000).default(''),
    sets: z.array(setSchema).max(50).default([]),
  })
  .strict();

const sessionFields = {
  clientId: z.string().trim().min(8).max(64),
  name: z.string().trim().max(120).default('Workout'),
  programId: objectId.nullable().default(null),
  dayId: objectId.nullable().default(null),
  startedAt: z.coerce.date(),
  activeDurationSec: z.number().int().min(0).max(86400).nullable().default(null),
  exercises: z.array(sessionExercise).max(40).default([]),
  notes: z.string().max(2000).default(''),
};

const notInFuture = (d) => !d || d.getTime() <= Date.now() + 5 * 60 * 1000;

const completedBody = z
  .object({
    ...sessionFields,
    endedAt: z.coerce.date().optional(),
  })
  .strict()
  .refine((b) => notInFuture(b.startedAt) && notInFuture(b.endedAt), {
    message: 'Dates cannot be in the future',
    path: ['startedAt'],
  })
  .refine((b) => !b.endedAt || b.endedAt >= b.startedAt, {
    message: 'endedAt must be after startedAt',
    path: ['endedAt'],
  });

const activeBody = z.object(sessionFields).strict();

const updateBody = z
  .object({
    name: z.string().trim().max(120),
    notes: z.string().max(2000),
    startedAt: z.coerce.date(),
    endedAt: z.coerce.date(),
    activeDurationSec: z.number().int().min(0).max(86400).nullable(),
    exercises: z.array(sessionExercise).max(40),
  })
  .partial()
  .strict();

const listQuery = paginationQuery.extend({
  from: z.coerce.date().optional(),
  to: z.coerce.date().optional(),
});

const previousQuery = z.object({
  exerciseIds: z
    .union([z.string(), z.array(z.string())])
    .transform((v) => [...new Set((Array.isArray(v) ? v : v.split(',')).map((s) => s.trim()).filter(Boolean))])
    .pipe(z.array(objectId).min(1).max(40)),
});

const router = Router();
router.use(requireAuth);

router.get('/', validate({ query: listQuery }), ctrl.list);
router.post('/', validate({ body: completedBody }), ctrl.create);
router.get('/active', ctrl.getActive);
router.put('/active', validate({ body: activeBody }), ctrl.putActive);
router.delete('/active', ctrl.deleteActive);
router.get('/previous', validate({ query: previousQuery }), ctrl.previous);
router.get('/:id', validate({ params: idParams }), ctrl.getOne);
router.patch('/:id', validate({ params: idParams, body: updateBody }), ctrl.update);
router.delete('/:id', validate({ params: idParams }), ctrl.remove);

export default router;
