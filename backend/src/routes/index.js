import { Router } from 'express';
import authRoutes from './authRoutes.js';
import calorieRoutes from './calorieRoutes.js';
import exerciseRoutes from './exerciseRoutes.js';
import programRoutes from './programRoutes.js';
import { prRoutes, rankRoutes, statsRoutes } from './progressRoutes.js';
import userRoutes from './userRoutes.js';
import workoutRoutes from './workoutRoutes.js';

/** All versioned API routes, mounted at /api/v1. */
const api = Router();

api.use('/auth', authRoutes);
api.use('/users', userRoutes);
api.use('/exercises', exerciseRoutes);
api.use('/programs', programRoutes);
api.use('/workouts', workoutRoutes);
api.use('/prs', prRoutes);
api.use('/ranks', rankRoutes);
api.use('/stats', statsRoutes);
api.use('/calories', calorieRoutes);

export default api;
