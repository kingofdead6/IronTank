import mongoose from 'mongoose';
import { jsonOptions } from '../utils/toJson.js';

export const PR_TYPES = ['maxWeight', 'maxRepsAtWeight', 'e1rm', 'maxVolumeSet'];

const { ObjectId } = mongoose.Schema.Types;

/**
 * One record-setting event. `value` units depend on type:
 *   maxWeight / e1rm → kg · maxRepsAtWeight → reps (at `weight` kg) · maxVolumeSet → kg × reps
 */
const personalRecordSchema = new mongoose.Schema(
  {
    userId: { type: ObjectId, ref: 'User', required: true },
    exerciseId: { type: ObjectId, ref: 'Exercise', required: true },
    type: { type: String, enum: PR_TYPES, required: true },
    value: { type: Number, required: true },
    weight: { type: Number, default: null },
    reps: { type: Number, default: null },
    previousValue: { type: Number, default: null },
    /** First value ever logged for this type: stored for history, not celebrated. */
    isBaseline: { type: Boolean, default: false },
    bodyweightKg: { type: Number, default: null },
    sessionId: { type: ObjectId, ref: 'WorkoutSession', required: true },
    achievedAt: { type: Date, required: true },
  },
  {
    timestamps: true,
    toJSON: jsonOptions(),
  },
);

personalRecordSchema.index({ userId: 1, achievedAt: -1 });
personalRecordSchema.index({ userId: 1, exerciseId: 1, type: 1, achievedAt: -1 });
personalRecordSchema.index({ sessionId: 1 });

export const PersonalRecord = mongoose.model('PersonalRecord', personalRecordSchema);
