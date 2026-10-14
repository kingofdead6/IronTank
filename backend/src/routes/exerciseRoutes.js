import { Router } from 'express';
import { z } from 'zod';
import * as ctrl from '../controllers/exerciseController.js';
import { requireAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { CATEGORIES, EQUIPMENT, LEVELS, MUSCLES } from '../models/Exercise.js';
import { idParams, paginationQuery } from '../utils/zod.js';

/** Accepts `?muscle=chest&muscle=lats` or `?muscle=chest,lats`. */
const multi = (values) =>
  z
    .union([z.string(), z.array(z.string())])
    .transform((v) => (Array.isArray(v) ? v : v.split(',')).map((s) => s.trim()).filter(Boolean))
    .pipe(z.array(z.enum(values)))
    .optional();

const listQuery = paginationQuery.extend({
  q: z.string().trim().max(100).optional(),
  muscle: multi(MUSCLES),
  equipment: multi(EQUIPMENT),
  category: multi(CATEGORIES),
  level: multi(LEVELS),
  scope: z.enum(['all', 'global', 'custom']).default('all'),
});

const exerciseBody = z
  .object({
    name: z.string().trim().min(2).max(120),
    primaryMuscles: z.array(z.enum(MUSCLES)).min(1).max(6),
    secondaryMuscles: z.array(z.enum(MUSCLES)).max(10).default([]),
    equipment: z.enum(EQUIPMENT).default('none'),
    category: z.enum(CATEGORIES).default('strength'),
    level: z.enum(LEVELS).default('beginner'),
    instructions: z.array(z.string().trim().min(1).max(1000)).max(20).default([]),
    images: z.array(z.string().url().max(2048)).max(6).default([]),
    metValue: z.number().min(1).max(20).optional(),
    isBodyweight: z.boolean().optional(),
  })
  .strict();

// For PATCH, drop defaults so omitted fields stay untouched.
const updateBody = z
  .object({
    name: z.string().trim().min(2).max(120),
    primaryMuscles: z.array(z.enum(MUSCLES)).min(1).max(6),
    secondaryMuscles: z.array(z.enum(MUSCLES)).max(10),
    equipment: z.enum(EQUIPMENT),
    category: z.enum(CATEGORIES),
    level: z.enum(LEVELS),
    instructions: z.array(z.string().trim().min(1).max(1000)).max(20),
    images: z.array(z.string().url().max(2048)).max(6),
    metValue: z.number().min(1).max(20),
    isBodyweight: z.boolean(),
  })
  .partial()
  .strict();

const router = Router();
router.use(requireAuth);

router.get('/', validate({ query: listQuery }), ctrl.list);
router.get('/filters', ctrl.filters);
router.get('/:id', validate({ params: idParams }), ctrl.getOne);
router.post('/', validate({ body: exerciseBody }), ctrl.create);
router.patch('/:id', validate({ params: idParams, body: updateBody }), ctrl.update);
router.delete('/:id', validate({ params: idParams }), ctrl.remove);

export default router;
