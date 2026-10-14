import mongoose from 'mongoose';
import { jsonOptions } from '../utils/toJson.js';

export const SEXES = ['male', 'female'];
export const UNITS = ['kg', 'lb'];
export const ACTIVITY_LEVELS = ['sedentary', 'light', 'moderate', 'active', 'very_active'];
export const GOALS = ['cut', 'maintain', 'bulk'];

const bodyweightEntrySchema = new mongoose.Schema(
  {
    kg: { type: Number, required: true, min: 20, max: 400 },
    date: { type: Date, required: true, default: Date.now },
  },
  { _id: true },
);

const userSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true, select: false },
    username: { type: String, required: true, trim: true, minlength: 2, maxlength: 32 },
    avatarUrl: { type: String, default: null },
    sex: { type: String, enum: SEXES, default: null },
    birthDate: { type: Date, default: null },
    heightCm: { type: Number, min: 100, max: 250, default: null },
    bodyweightKg: { type: Number, min: 20, max: 400, default: null },
    bodyweightHistory: { type: [bodyweightEntrySchema], default: [] },
    unit: { type: String, enum: UNITS, default: 'kg' },
    activityLevel: { type: String, enum: ACTIVITY_LEVELS, default: 'moderate' },
    goal: { type: String, enum: GOALS, default: 'maintain' },
    restTimerDefaultSec: { type: Number, min: 15, max: 600, default: 90 },
    onboardingComplete: { type: Boolean, default: false },
    /** Manual daily calorie target; null = use the TDEE recommendation for `goal`. */
    calorieTargetKcal: { type: Number, min: 800, max: 10000, default: null },
    /** Last seen tier index per lift (+ "overall"), used to detect rank changes. */
    rankTiers: { type: mongoose.Schema.Types.Mixed, default: {} },
  },
  {
    timestamps: true,
    toJSON: jsonOptions((ret) => {
      delete ret.passwordHash;
      // History is served from its own paginated endpoint.
      delete ret.bodyweightHistory;
      delete ret.rankTiers;
    }),
  },
);

userSchema.index({ 'bodyweightHistory.date': -1 });

export const User = mongoose.model('User', userSchema);
