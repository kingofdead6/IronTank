import mongoose from 'mongoose';
import { z } from 'zod';

/** Shared zod building blocks used by route-level schemas. */

export const objectId = z
  .string()
  .refine((v) => mongoose.Types.ObjectId.isValid(v) && /^[a-f\d]{24}$/i.test(v), 'Invalid id');

export const idParams = z.object({ id: objectId });

export const MAX_PAGE_SIZE = 100;

export const paginationQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(MAX_PAGE_SIZE).default(20),
});

/** ISO date string (YYYY-MM-DD) used for day-bucketed resources. */
export const isoDay = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected YYYY-MM-DD');

export const email = z.string().trim().toLowerCase().email().max(254);
export const password = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(128, 'Password must be at most 128 characters');
