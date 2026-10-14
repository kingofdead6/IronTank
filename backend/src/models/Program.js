import mongoose from 'mongoose';
import { jsonOptions } from '../utils/toJson.js';

const { ObjectId } = mongoose.Schema.Types;

const programExerciseSchema = new mongoose.Schema(
  {
    exerciseId: { type: ObjectId, ref: 'Exercise', required: true },
    sets: { type: Number, min: 1, max: 20, default: 3 },
    repRange: {
      min: { type: Number, min: 1, max: 100, default: 8 },
      max: { type: Number, min: 1, max: 100, default: 12 },
    },
    targetRPE: { type: Number, min: 1, max: 10, default: null },
    restSeconds: { type: Number, min: 0, max: 900, default: 90 },
    notes: { type: String, maxlength: 500, default: '' },
  },
  { _id: true },
);

const programDaySchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 60 },
    exercises: { type: [programExerciseSchema], default: [] },
  },
  { _id: true },
);

const programSchema = new mongoose.Schema(
  {
    /** null for built-in templates. */
    userId: { type: ObjectId, ref: 'User', default: null },
    name: { type: String, required: true, trim: true, maxlength: 80 },
    description: { type: String, maxlength: 1000, default: '' },
    weeks: { type: Number, min: 1, max: 52, default: 8 },
    days: { type: [programDaySchema], default: [] },
    isTemplate: { type: Boolean, default: false },
    /** Stable key for seeded templates (e.g. "ppl"), so re-seeding updates in place. */
    templateKey: { type: String, default: null },
    /** Template this program was copied from, if any. */
    sourceTemplateId: { type: ObjectId, ref: 'Program', default: null },
    isActive: { type: Boolean, default: false },
    activatedAt: { type: Date, default: null },
  },
  {
    timestamps: true,
    toJSON: jsonOptions(),
  },
);

programSchema.index({ userId: 1, updatedAt: -1 });
programSchema.index({ templateKey: 1 }, { unique: true, partialFilterExpression: { isTemplate: true } });
// Only one active program per user.
programSchema.index(
  { userId: 1 },
  { unique: true, partialFilterExpression: { isActive: true }, name: 'one_active_program_per_user' },
);

export const Program = mongoose.model('Program', programSchema);
