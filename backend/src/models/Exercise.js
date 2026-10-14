import mongoose from 'mongoose';
import { jsonOptions } from '../utils/toJson.js';

export const CATEGORIES = ['strength', 'cardio', 'stretching'];
export const LEVELS = ['beginner', 'intermediate', 'expert'];
export const EQUIPMENT = [
  'barbell',
  'dumbbell',
  'kettlebells',
  'cable',
  'machine',
  'body only',
  'bands',
  'e-z curl bar',
  'medicine ball',
  'exercise ball',
  'foam roll',
  'other',
  'none',
];
export const MUSCLES = [
  'abdominals',
  'abductors',
  'adductors',
  'biceps',
  'calves',
  'chest',
  'forearms',
  'glutes',
  'hamstrings',
  'lats',
  'lower back',
  'middle back',
  'neck',
  'quadriceps',
  'shoulders',
  'traps',
  'triceps',
];

const exerciseSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 120 },
    slug: { type: String, required: true, lowercase: true, trim: true },
    primaryMuscles: { type: [{ type: String, enum: MUSCLES }], default: [] },
    secondaryMuscles: { type: [{ type: String, enum: MUSCLES }], default: [] },
    equipment: { type: String, enum: EQUIPMENT, default: 'none' },
    category: { type: String, enum: CATEGORIES, required: true },
    /** Original category from free-exercise-db (e.g. "powerlifting"); null for custom. */
    sourceCategory: { type: String, default: null },
    force: { type: String, enum: ['push', 'pull', 'static', null], default: null },
    mechanic: { type: String, enum: ['compound', 'isolation', null], default: null },
    level: { type: String, enum: LEVELS, default: 'beginner' },
    instructions: { type: [String], default: [] },
    images: { type: [String], default: [] },
    metValue: { type: Number, min: 1, max: 20, required: true },
    /** When true, a set's weight is *added* load and effective load = bodyweight + weight. */
    isBodyweight: { type: Boolean, default: false },
    /** Ranked lift this exercise counts toward (see config/lifts.js), if any. */
    liftKey: { type: String, default: null },
    isCustom: { type: Boolean, default: false },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', default: null },
    sourceId: { type: String, default: null },
  },
  {
    timestamps: true,
    toJSON: jsonOptions(),
  },
);

// Global slugs are unique; custom exercises are unique per creator.
exerciseSchema.index({ slug: 1, createdBy: 1 }, { unique: true });
exerciseSchema.index({ name: 1 });
exerciseSchema.index({ createdBy: 1, name: 1 });
exerciseSchema.index({ primaryMuscles: 1 });
exerciseSchema.index({ equipment: 1 });
exerciseSchema.index({ category: 1 });
exerciseSchema.index({ liftKey: 1 });

export const Exercise = mongoose.model('Exercise', exerciseSchema);
