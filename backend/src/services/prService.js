import { Exercise } from '../models/Exercise.js';
import { PersonalRecord } from '../models/PersonalRecord.js';
import { WorkoutSession } from '../models/WorkoutSession.js';
import { paginate } from '../utils/pagination.js';
import { setE1rm } from './oneRepMax.js';

/** Only these set types can set records (warm-ups and drop sets can't). */
export const QUALIFYING_SET_TYPES = ['working', 'failure'];

/** Weights are compared at 0.01 kg precision so lb→kg conversions still match. */
export const weightKey = (w) => (Math.round(Number(w) * 100) / 100).toFixed(2);

const emptyBests = () => ({ maxWeight: null, e1rm: null, maxVolumeSet: null, repsAtWeight: new Map() });

/**
 * Builds the current bests per exercise from existing PersonalRecord docs.
 * @returns {Map<string, ReturnType<typeof emptyBests>>}
 */
export function bestsFromRecords(records) {
  const bests = new Map();
  for (const r of records) {
    const key = r.exerciseId.toString();
    if (!bests.has(key)) bests.set(key, emptyBests());
    const b = bests.get(key);
    if (r.type === 'maxRepsAtWeight') {
      const wk = weightKey(r.weight);
      b.repsAtWeight.set(wk, Math.max(b.repsAtWeight.get(wk) ?? 0, r.value));
    } else {
      b[r.type] = b[r.type] === null ? r.value : Math.max(b[r.type], r.value);
    }
  }
  return bests;
}

/**
 * Best values a single session achieved for one exercise.
 * Within a session each record type counts once (its best set).
 */
export function sessionBestsForExercise(sets, exercise, bodyweightKg) {
  const out = { maxWeight: null, e1rm: null, maxVolumeSet: null, repsAtWeight: new Map() };
  for (const set of sets) {
    if (!set.completed || !QUALIFYING_SET_TYPES.includes(set.type)) continue;
    const reps = Number(set.reps) || 0;
    const weight = Number(set.weight) || 0;
    if (reps < 1) continue;

    if (weight > 0) {
      if (out.maxWeight === null || weight > out.maxWeight.value) out.maxWeight = { value: weight, weight, reps };
      const volume = weight * reps;
      if (out.maxVolumeSet === null || volume > out.maxVolumeSet.value) {
        out.maxVolumeSet = { value: volume, weight, reps };
      }
    }

    const e1rm = setE1rm(set, exercise, bodyweightKg);
    if (e1rm && (out.e1rm === null || e1rm > out.e1rm.value)) out.e1rm = { value: e1rm, weight, reps };

    // Reps at a given weight (weight 0 on a bodyweight exercise = plain bodyweight reps).
    if (weight > 0 || exercise.isBodyweight) {
      const wk = weightKey(weight);
      const prev = out.repsAtWeight.get(wk);
      if (!prev || reps > prev.value) out.repsAtWeight.set(wk, { value: reps, weight: Number(wk), reps });
    }
  }
  return out;
}

/**
 * Compares one session against the running bests and returns the records it sets.
 * Mutates `bests` so sessions can be folded chronologically.
 *
 * A first-ever value for a type is a *baseline* (stored, not celebrated);
 * beating an earlier value is a real PR.
 *
 * @param {{ exercises: Array<{ exerciseId:any, sets:any[] }>, bodyweightKg?: number }} session
 * @param {Map<string, {isBodyweight:boolean}>} exercisesById
 * @param {Map<string, ReturnType<typeof emptyBests>>} bests
 * @param {{ onlyExerciseIds?: Set<string> }} [opts]
 */
export function evaluateSession(session, exercisesById, bests, { onlyExerciseIds } = {}) {
  const records = [];
  // An exercise may appear twice in a session; merge its sets first.
  const setsByExercise = new Map();
  for (const ex of session.exercises ?? []) {
    const id = ex.exerciseId.toString();
    if (onlyExerciseIds && !onlyExerciseIds.has(id)) continue;
    if (!exercisesById.has(id)) continue;
    setsByExercise.set(id, [...(setsByExercise.get(id) ?? []), ...(ex.sets ?? [])]);
  }

  for (const [id, sets] of setsByExercise) {
    const meta = exercisesById.get(id);
    const sb = sessionBestsForExercise(sets, meta, session.bodyweightKg);
    if (!bests.has(id)) bests.set(id, emptyBests());
    const b = bests.get(id);

    for (const type of ['maxWeight', 'e1rm', 'maxVolumeSet']) {
      const candidate = sb[type];
      if (!candidate) continue;
      const previous = b[type];
      if (previous === null || candidate.value > previous) {
        records.push({
          exerciseId: id,
          type,
          value: candidate.value,
          weight: candidate.weight,
          reps: candidate.reps,
          previousValue: previous,
          isBaseline: previous === null,
        });
        b[type] = candidate.value;
      }
    }

    for (const [wk, candidate] of sb.repsAtWeight) {
      const previous = b.repsAtWeight.get(wk) ?? null;
      if (previous === null || candidate.value > previous) {
        records.push({
          exerciseId: id,
          type: 'maxRepsAtWeight',
          value: candidate.value,
          weight: candidate.weight,
          reps: candidate.reps,
          previousValue: previous,
          isBaseline: previous === null,
        });
        b.repsAtWeight.set(wk, candidate.value);
      }
    }
  }
  return records;
}

async function loadExerciseMeta(ids) {
  const docs = await Exercise.find({ _id: { $in: ids } }).select('name isBodyweight images primaryMuscles');
  return new Map(docs.map((d) => [d._id.toString(), d]));
}

const toDoc = (userId, session) => (r) => ({
  ...r,
  userId,
  sessionId: session._id,
  achievedAt: session.endedAt ?? session.startedAt,
  bodyweightKg: session.bodyweightKg ?? null,
});

/**
 * Deletes and recomputes all records for the given exercises by replaying the
 * user's completed sessions in order. Used after edits, deletions and backdated saves.
 */
export async function rebuildPRs(userId, exerciseIds) {
  const ids = [...new Set(exerciseIds.map(String))];
  if (!ids.length) return [];
  await PersonalRecord.deleteMany({ userId, exerciseId: { $in: ids } });

  const meta = await loadExerciseMeta(ids);
  const sessions = await WorkoutSession.find({
    userId,
    status: 'completed',
    'exercises.exerciseId': { $in: ids },
  })
    .sort({ startedAt: 1, _id: 1 })
    .lean();

  const bests = new Map();
  const only = new Set(ids);
  const docs = [];
  for (const s of sessions) {
    docs.push(...evaluateSession(s, meta, bests, { onlyExerciseIds: only }).map(toDoc(userId, s)));
  }
  if (docs.length) await PersonalRecord.insertMany(docs);
  return docs;
}

/**
 * Runs PR detection for a freshly saved session and returns its real PRs
 * (baselines excluded), each with exercise info for the celebration screen.
 */
export async function detectPRsForSession(userId, session) {
  const ids = [...new Set(session.exercises.map((e) => e.exerciseId.toString()))];
  if (!ids.length) return [];

  // A backdated session can invalidate later records, so replay instead.
  const newerExists = await WorkoutSession.exists({
    userId,
    status: 'completed',
    _id: { $ne: session._id },
    startedAt: { $gt: session.startedAt },
    'exercises.exerciseId': { $in: ids },
  });

  let created;
  if (newerExists) {
    const all = await rebuildPRs(userId, ids);
    created = all.filter((d) => d.sessionId.toString() === session._id.toString());
  } else {
    const meta = await loadExerciseMeta(ids);
    const existing = await PersonalRecord.find({ userId, exerciseId: { $in: ids } }).lean();
    const bests = bestsFromRecords(existing);
    created = evaluateSession(session, meta, bests).map(toDoc(userId, session));
    if (created.length) await PersonalRecord.insertMany(created);
  }

  const meta = await loadExerciseMeta(ids);
  return created
    .filter((r) => !r.isBaseline)
    .map((r) => {
      const ex = meta.get(r.exerciseId.toString());
      return {
        exerciseId: r.exerciseId.toString(),
        exerciseName: ex?.name ?? 'Exercise',
        exerciseImage: ex?.images?.[0] ?? null,
        type: r.type,
        value: r.value,
        previousValue: r.previousValue,
        weight: r.weight,
        reps: r.reps,
        achievedAt: r.achievedAt,
      };
    });
}

// ---- Queries ---------------------------------------------------------------

const withExercise = { path: 'exerciseId', select: 'name images primaryMuscles isBodyweight' };

function serializeRecord(r) {
  const json = r.toJSON();
  const ex = r.exerciseId && typeof r.exerciseId === 'object' && r.exerciseId.name ? r.exerciseId : null;
  return {
    ...json,
    exerciseId: ex ? ex._id.toString() : json.exerciseId?.toString(),
    sessionId: json.sessionId?.toString(),
    exercise: ex ? { id: ex._id.toString(), name: ex.name, image: ex.images?.[0] ?? null } : null,
  };
}

/** Latest records across all exercises (celebrated PRs only unless asked). */
export async function listRecords(userId, { page, limit, type, includeBaselines }) {
  const filter = { userId };
  if (!includeBaselines) filter.isBaseline = false;
  if (type) filter.type = type;
  const result = await paginate(PersonalRecord, filter, {
    page,
    limit,
    sort: { achievedAt: -1, _id: -1 },
    populate: withExercise,
  });
  return { ...result, data: result.data.map(serializeRecord) };
}

/** Current bests for one exercise plus its paginated record history (baselines included). */
export async function recordsForExercise(userId, exerciseId, { page, limit }) {
  const all = await PersonalRecord.find({ userId, exerciseId }).lean();
  const bests = bestsFromRecords(all).get(exerciseId.toString());
  const latestOf = (type, value) =>
    all
      .filter((r) => r.type === type && r.value === value)
      .sort((a, b) => b.achievedAt - a.achievedAt)[0];
  const current = bests
    ? {
        maxWeight: bests.maxWeight === null ? null : pickRecord(latestOf('maxWeight', bests.maxWeight)),
        e1rm: bests.e1rm === null ? null : pickRecord(latestOf('e1rm', bests.e1rm)),
        maxVolumeSet: bests.maxVolumeSet === null ? null : pickRecord(latestOf('maxVolumeSet', bests.maxVolumeSet)),
        repsAtWeight: [...bests.repsAtWeight.entries()]
          .map(([w, reps]) => ({ weight: Number(w), reps }))
          .sort((a, b) => b.weight - a.weight),
      }
    : { maxWeight: null, e1rm: null, maxVolumeSet: null, repsAtWeight: [] };

  const history = await paginate(
    PersonalRecord,
    { userId, exerciseId },
    { page, limit, sort: { achievedAt: -1, _id: -1 }, populate: withExercise },
  );
  return { current, history: { ...history, data: history.data.map(serializeRecord) } };
}

function pickRecord(r) {
  return r ? { value: r.value, weight: r.weight, reps: r.reps, achievedAt: r.achievedAt, sessionId: r.sessionId.toString() } : null;
}
