import mongoose from 'mongoose';
import { jsonOptions } from '../utils/toJson.js';

const entrySchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true, maxlength: 120 },
    kcal: { type: Number, required: true, min: 0, max: 10000 },
    protein: { type: Number, min: 0, max: 1000, default: 0 },
    carbs: { type: Number, min: 0, max: 2000, default: 0 },
    fat: { type: Number, min: 0, max: 1000, default: 0 },
    loggedAt: { type: Date, default: Date.now },
  },
  { _id: true },
);

/** One document per user per local calendar day. */
const calorieLogSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    /** Local calendar day as YYYY-MM-DD (the client's day, not UTC). */
    date: { type: String, required: true, match: /^\d{4}-\d{2}-\d{2}$/ },
    entries: { type: [entrySchema], default: [] },
    /** Daily target snapshot (kcal), so past days keep the target that applied then. */
    targetKcal: { type: Number, min: 0, max: 10000, default: null },
  },
  {
    timestamps: true,
    toJSON: jsonOptions(),
  },
);

calorieLogSchema.index({ userId: 1, date: -1 }, { unique: true });

export const CalorieLog = mongoose.model('CalorieLog', calorieLogSchema);
