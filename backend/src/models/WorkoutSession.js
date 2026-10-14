import mongoose from 'mongoose';
import { jsonOptions } from '../utils/toJson.js';

export const SET_TYPES = ['warmup', 'working', 'dropset', 'failure'];
export const SESSION_STATUSES = ['active', 'completed'];

const { ObjectId } = mongoose.Schema.Types;

const setSchema = new mongoose.Schema(
  {
    /** kg. For bodyweight exercises this is added load (negative = assistance). */
    weight: { type: Number, default: 0, min: -300, max: 1000 },
    reps: { type: Number, default: 0, min: 0, max: 1000 },
    rpe: { type: Number, min: 1, max: 10, default: null },
    type: { type: String, enum: SET_TYPES, default: 'working' },
    completed: { type: Boolean, default: false },
    /** Seconds actually rested after this set. */
    restTaken: { type: Number, min: 0, max: 7200, default: null },
    completedAt: { type: Date, default: null },
  },
  { _id: true },
);

const sessionExerciseSchema = new mongoose.Schema(
  {
    exerciseId: { type: ObjectId, ref: 'Exercise', required: true },
    /** Snapshot so history still reads well if a custom exercise is deleted. */
    exerciseName: { type: String, default: '' },
    restSeconds: { type: Number, min: 0, max: 900, default: null },
    notes: { type: String, maxlength: 1000, default: '' },
    sets: { type: [setSchema], default: [] },
  },
  { _id: true },
);

const workoutSessionSchema = new mongoose.Schema(
  {
    userId: { type: ObjectId, ref: 'User', required: true },
    /** Generated on the device; makes offline sync retries idempotent. */
    clientId: { type: String, required: true, maxlength: 64 },
    status: { type: String, enum: SESSION_STATUSES, default: 'completed' },
    name: { type: String, maxlength: 120, default: 'Workout' },
    programId: { type: ObjectId, ref: 'Program', default: null },
    dayId: { type: ObjectId, default: null },
    startedAt: { type: Date, required: true },
    endedAt: { type: Date, default: null },
    /** Wall-clock length in seconds. */
    durationSec: { type: Number, min: 0, default: 0 },
    /** Time the session timer was running (excludes pauses); used for calories. */
    activeDurationSec: { type: Number, min: 0, default: null },
    exercises: { type: [sessionExerciseSchema], default: [] },
    notes: { type: String, maxlength: 2000, default: '' },
    /** Σ weight × reps of completed non-warm-up sets (kg). */
    totalVolume: { type: Number, default: 0 },
    caloriesBurned: { type: Number, default: 0 },
    /** Bodyweight at the time of the session, used for e1RM of bodyweight lifts and ranks. */
    bodyweightKg: { type: Number, default: null },
    prCount: { type: Number, default: 0 },
  },
  {
    timestamps: true,
    toJSON: jsonOptions(),
  },
);

workoutSessionSchema.index({ userId: 1, clientId: 1 }, { unique: true });
workoutSessionSchema.index({ userId: 1, status: 1, startedAt: -1 });
workoutSessionSchema.index({ userId: 1, 'exercises.exerciseId': 1, startedAt: -1 });
workoutSessionSchema.index({ userId: 1, programId: 1, startedAt: -1 });
// At most one in-progress draft per user.
workoutSessionSchema.index(
  { userId: 1 },
  { unique: true, partialFilterExpression: { status: 'active' }, name: 'one_active_per_user' },
);

export const WorkoutSession = mongoose.model('WorkoutSession', workoutSessionSchema);
