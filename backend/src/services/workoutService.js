import mongoose from 'mongoose';
import { Exercise } from '../models/Exercise.js';
import { PersonalRecord } from '../models/PersonalRecord.js';
import { User } from '../models/User.js';
import { WorkoutSession } from '../models/WorkoutSession.js';
import { AppError } from '../utils/AppError.js';
import { paginate } from '../utils/pagination.js';
import { sessionCalories } from './calorieService.js';
import { detectPRsForSession, rebuildPRs } from './prService.js';
import { refreshRanksAndDiff } from './rankService.js';

/** Σ weight × reps over completed, non-warm-up sets (logged weight, kg). */
export function totalVolume(exercises) {
  let volume = 0;
  for (const ex of exercises ?? []) {
    for (const s of ex.sets ?? []) {
      if (s.completed && s.type !== 'warmup' && s.weight > 0 && s.reps > 0) volume += s.weight * s.reps;
    }
  }
  return Math.round(volume * 10) / 10;
}

/** Loads exercises the user can see, failing if any id is unknown. */
async function resolveExercises(userId, exercises) {
  const ids = [...new Set((exercises ?? []).map((e) => e.exerciseId.toString()))];
  const docs = await Exercise.find({
    _id: { $in: ids },
    $or: [{ createdBy: null }, { createdBy: userId }],
  }).select('name metValue isBodyweight');
  const byId = new Map(docs.map((d) => [d._id.toString(), d]));
  const missing = ids.filter((id) => !byId.has(id));
  if (missing.length) {
    throw new AppError(422, 'UNKNOWN_EXERCISE', 'One or more exercises do not exist', { missing });
  }
  return byId;
}

/** Negative weight (assistance) only makes sense on bodyweight exercises. */
function assertWeights(exercises, byId) {
  for (const ex of exercises) {
    const meta = byId.get(ex.exerciseId.toString());
    if (!meta.isBodyweight && ex.sets.some((s) => s.weight < 0)) {
      throw new AppError(422, 'INVALID_WEIGHT', `Negative weight is only allowed on bodyweight exercises (${meta.name})`);
    }
  }
}

function withNameSnapshots(exercises, byId) {
  return exercises.map((ex) => ({ ...ex, exerciseName: byId.get(ex.exerciseId.toString()).name }));
}

/** Derives duration, volume and calories for a completed session (mutates the doc). */
function applyDerivedFields(session, byId) {
  const start = new Date(session.startedAt).getTime();
  const end = new Date(session.endedAt ?? Date.now()).getTime();
  if (end < start) throw AppError.badRequest('endedAt must be after startedAt');
  session.durationSec = Math.round((end - start) / 1000);
  if (session.activeDurationSec != null) {
    session.activeDurationSec = Math.min(session.activeDurationSec, session.durationSec);
  }
  session.totalVolume = totalVolume(session.exercises);
  const { kcal, usedDefaultBodyweight } = sessionCalories(session, byId, session.bodyweightKg);
  session.caloriesBurned = kcal;
  return { kcal, usedDefaultBodyweight };
}

/** Recounts celebrated PRs per session after records were rebuilt. */
async function syncPrCounts(userId, exerciseIds) {
  const sessions = await WorkoutSession.find({
    userId,
    status: 'completed',
    'exercises.exerciseId': { $in: exerciseIds },
  }).select('_id');
  if (!sessions.length) return;
  // Aggregation pipelines don't cast types, so convert the id explicitly.
  const counts = await PersonalRecord.aggregate([
    { $match: { userId: new mongoose.Types.ObjectId(String(userId)), isBaseline: false } },
    { $group: { _id: '$sessionId', n: { $sum: 1 } } },
  ]);
  const byId = new Map(counts.map((c) => [c._id.toString(), c.n]));
  await WorkoutSession.bulkWrite(
    sessions.map((s) => ({
      updateOne: { filter: { _id: s._id }, update: { $set: { prCount: byId.get(s._id.toString()) ?? 0 } } },
    })),
  );
}

async function celebratedPRsOf(sessionId) {
  const prs = await PersonalRecord.find({ sessionId, isBaseline: false }).populate('exerciseId', 'name images');
  return prs.map((r) => ({
    exerciseId: r.exerciseId?._id?.toString() ?? null,
    exerciseName: r.exerciseId?.name ?? 'Exercise',
    exerciseImage: r.exerciseId?.images?.[0] ?? null,
    type: r.type,
    value: r.value,
    previousValue: r.previousValue,
    weight: r.weight,
    reps: r.reps,
    achievedAt: r.achievedAt,
  }));
}

/**
 * Saves a finished workout: derives totals and calories, detects PRs, updates
 * ranks. Idempotent on `clientId`: re-sending a saved session returns it unchanged.
 */
export async function saveCompletedSession(userId, data) {
  const existing = await WorkoutSession.findOne({ userId, clientId: data.clientId });
  if (existing?.status === 'completed') {
    return {
      session: existing,
      newPRs: await celebratedPRsOf(existing._id),
      rankChanges: [],
      calories: { kcal: existing.caloriesBurned, isEstimate: true },
      duplicate: true,
    };
  }

  const user = await User.findById(userId);
  if (!user) throw AppError.notFound('User');
  const byId = await resolveExercises(userId, data.exercises);
  assertWeights(data.exercises, byId);

  const session = existing ?? new WorkoutSession({ userId, clientId: data.clientId });
  session.set({
    ...data,
    exercises: withNameSnapshots(data.exercises, byId),
    status: 'completed',
    endedAt: data.endedAt ?? new Date(),
    bodyweightKg: user.bodyweightKg ?? null,
  });
  const { kcal, usedDefaultBodyweight } = applyDerivedFields(session, byId);

  // Finishing a workout discards any other in-progress draft.
  await WorkoutSession.deleteMany({ userId, status: 'active', _id: { $ne: session._id } });
  try {
    await session.save();
  } catch (err) {
    if (err?.code === 11000) return saveCompletedSession(userId, data); // concurrent retry
    throw err;
  }

  const newPRs = await detectPRsForSession(userId, session);
  if (newPRs.length) {
    session.prCount = newPRs.length;
    await session.save();
  }
  const { changes } = await refreshRanksAndDiff(userId);

  return {
    session,
    newPRs,
    rankChanges: changes,
    calories: { kcal, isEstimate: true, usedDefaultBodyweight },
    duplicate: false,
  };
}

export async function listSessions(userId, { page, limit, from, to }) {
  const filter = { userId, status: 'completed' };
  if (from || to) {
    filter.startedAt = {};
    if (from) filter.startedAt.$gte = from;
    if (to) filter.startedAt.$lte = to;
  }
  return paginate(WorkoutSession, filter, { page, limit, sort: { startedAt: -1, _id: -1 } });
}

export async function getSession(userId, id) {
  const session = await WorkoutSession.findOne({ _id: id, userId, status: 'completed' });
  if (!session) throw AppError.notFound('Workout');
  return session;
}

/** Edits a saved workout and recomputes every derived value it affects. */
export async function updateSession(userId, id, data) {
  const session = await getSession(userId, id);
  const before = session.exercises.map((e) => e.exerciseId.toString());

  if (data.exercises) {
    const byIdNew = await resolveExercises(userId, data.exercises);
    assertWeights(data.exercises, byIdNew);
    data = { ...data, exercises: withNameSnapshots(data.exercises, byIdNew) };
  }
  session.set(data);
  const byId = await resolveExercises(userId, session.exercises.map((e) => e.toObject()));
  applyDerivedFields(session, byId);
  await session.save();

  const affected = [...new Set([...before, ...session.exercises.map((e) => e.exerciseId.toString())])];
  await rebuildPRs(userId, affected);
  await syncPrCounts(userId, affected);
  const { changes } = await refreshRanksAndDiff(userId);
  return { session: await getSession(userId, id), rankChanges: changes };
}

export async function deleteSession(userId, id) {
  const session = await getSession(userId, id);
  const affected = [...new Set(session.exercises.map((e) => e.exerciseId.toString()))];
  await session.deleteOne();
  await PersonalRecord.deleteMany({ sessionId: session._id });
  await rebuildPRs(userId, affected);
  await syncPrCounts(userId, affected);
  await refreshRanksAndDiff(userId);
}

// ---- Active (in-progress) workout draft -----------------------------------

export async function getActive(userId) {
  return WorkoutSession.findOne({ userId, status: 'active' });
}

/** Creates or replaces the server copy of the in-progress workout. */
export async function putActive(userId, data) {
  const completed = await WorkoutSession.exists({ userId, clientId: data.clientId, status: 'completed' });
  if (completed) throw AppError.conflict('This workout was already saved', 'ALREADY_COMPLETED');

  const byId = await resolveExercises(userId, data.exercises);
  await WorkoutSession.deleteMany({ userId, status: 'active', clientId: { $ne: data.clientId } });
  return WorkoutSession.findOneAndUpdate(
    { userId, clientId: data.clientId, status: 'active' },
    {
      $set: { ...data, exercises: withNameSnapshots(data.exercises, byId), endedAt: null },
      $setOnInsert: { userId, status: 'active' },
    },
    { upsert: true, new: true, runValidators: true },
  );
}

export async function deleteActive(userId) {
  await WorkoutSession.deleteMany({ userId, status: 'active' });
}

/**
 * Sets from the most recent completed session of each exercise, for the
 * "previous" ghost values in the active-workout screen.
 */
export async function previousSets(userId, exerciseIds) {
  const result = {};
  await Promise.all(
    exerciseIds.map(async (id) => {
      const s = await WorkoutSession.findOne({ userId, status: 'completed', 'exercises.exerciseId': id })
        .sort({ startedAt: -1 })
        .select('startedAt exercises')
        .lean();
      if (!s) {
        result[id] = null;
        return;
      }
      const sets = s.exercises.filter((e) => e.exerciseId.toString() === id).flatMap((e) => e.sets);
      result[id] = {
        sessionId: s._id.toString(),
        date: s.startedAt,
        sets: sets.map(({ weight, reps, rpe, type }) => ({ weight, reps, rpe, type })),
      };
    }),
  );
  return result;
}
