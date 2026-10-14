import { GROUP_BY_MUSCLE, MUSCLE_GROUPS } from '../config/lifts.js';
import { Exercise } from '../models/Exercise.js';
import { PersonalRecord } from '../models/PersonalRecord.js';
import { WorkoutSession } from '../models/WorkoutSession.js';
import { AppError } from '../utils/AppError.js';
import { addDays, daysBetween, localDay, weekStart } from '../utils/dates.js';
import { setE1rm } from './oneRepMax.js';
import { QUALIFYING_SET_TYPES } from './prService.js';

/** Streak sessions older than this are not scanned. */
const STREAK_LOOKBACK_DAYS = 2 * 365;

/**
 * Consecutive-day and consecutive-week streaks ending today. A streak stays
 * alive until the current day/week is over, so not having trained *yet* today
 * doesn't reset it.
 *
 * @param {string[]} trainedDays  local 'YYYY-MM-DD' days with ≥1 session
 * @param {string} today
 */
export function computeStreaks(trainedDays, today) {
  const days = new Set(trainedDays);
  const weeks = new Set(trainedDays.map(weekStart));

  let dayStreak = 0;
  let cursor = days.has(today) ? today : addDays(today, -1);
  while (days.has(cursor)) {
    dayStreak += 1;
    cursor = addDays(cursor, -1);
  }

  let weekStreak = 0;
  const thisWeek = weekStart(today);
  let w = weeks.has(thisWeek) ? thisWeek : addDays(thisWeek, -7);
  while (weeks.has(w)) {
    weekStreak += 1;
    w = addDays(w, -7);
  }

  return { days: dayStreak, weeks: weekStreak };
}

/**
 * Completed non-warm-up sets per muscle group. Primary muscles count 1 per set,
 * secondary muscles 0.5, split evenly when an exercise lists several.
 */
export function muscleDistribution(sessions, exercisesById) {
  const totals = Object.fromEntries(Object.keys(MUSCLE_GROUPS).map((g) => [g, 0]));
  for (const s of sessions) {
    for (const ex of s.exercises) {
      const meta = exercisesById.get(ex.exerciseId.toString());
      if (!meta) continue;
      const sets = ex.sets.filter((set) => set.completed && set.type !== 'warmup').length;
      if (!sets) continue;
      const credit = (muscles, weight) => {
        const groups = muscles.map((m) => GROUP_BY_MUSCLE[m]).filter(Boolean);
        for (const g of groups) totals[g] += (sets * weight) / groups.length;
      };
      credit(meta.primaryMuscles ?? [], 1);
      credit(meta.secondaryMuscles ?? [], 0.5);
    }
  }
  const sum = Object.values(totals).reduce((a, b) => a + b, 0);
  return Object.entries(totals).map(([group, sets]) => ({
    group,
    sets: Math.round(sets * 10) / 10,
    percent: sum ? Math.round((sets / sum) * 1000) / 10 : 0,
  }));
}

export async function overview(userId, { weeks, tz, now = new Date() }) {
  const today = localDay(now, tz);
  const firstWeek = addDays(weekStart(today), -7 * (weeks - 1));
  const lookbackStart = addDays(today, -STREAK_LOOKBACK_DAYS);

  // One query: everything needed for both the window stats and the streak.
  const sessions = await WorkoutSession.find({
    userId,
    status: 'completed',
    startedAt: { $gte: new Date(new Date(`${lookbackStart}T00:00:00Z`).getTime() - 14 * 3600 * 1000) },
  })
    .select('startedAt durationSec totalVolume caloriesBurned exercises prCount')
    .sort({ startedAt: 1 })
    .lean();

  const withDay = sessions.map((s) => ({ ...s, day: localDay(s.startedAt, tz) }));
  const inWindow = withDay.filter((s) => s.day >= firstWeek && s.day <= today);

  const weekly = [];
  for (let i = 0; i < weeks; i += 1) {
    const ws = addDays(firstWeek, 7 * i);
    const we = addDays(ws, 6);
    const list = inWindow.filter((s) => s.day >= ws && s.day <= we);
    weekly.push({
      weekStart: ws,
      sessions: list.length,
      volume: Math.round(list.reduce((sum, s) => sum + (s.totalVolume || 0), 0)),
      durationSec: list.reduce((sum, s) => sum + (s.durationSec || 0), 0),
    });
  }

  const heatmapByDay = new Map();
  for (const s of inWindow) {
    const d = heatmapByDay.get(s.day) ?? { date: s.day, sessions: 0, volume: 0 };
    d.sessions += 1;
    d.volume += s.totalVolume || 0;
    heatmapByDay.set(s.day, d);
  }

  const exerciseIds = [...new Set(inWindow.flatMap((s) => s.exercises.map((e) => e.exerciseId.toString())))];
  const metas = await Exercise.find({ _id: { $in: exerciseIds } }).select('primaryMuscles secondaryMuscles').lean();
  const metaById = new Map(metas.map((m) => [m._id.toString(), m]));

  return {
    range: { from: firstWeek, to: today, weeks, tz },
    totals: {
      sessions: inWindow.length,
      volume: Math.round(inWindow.reduce((sum, s) => sum + (s.totalVolume || 0), 0)),
      durationSec: inWindow.reduce((sum, s) => sum + (s.durationSec || 0), 0),
      calories: inWindow.reduce((sum, s) => sum + (s.caloriesBurned || 0), 0),
      prs: inWindow.reduce((sum, s) => sum + (s.prCount || 0), 0),
      avgSessionsPerWeek: Math.round((inWindow.length / weeks) * 10) / 10,
    },
    streak: computeStreaks(withDay.map((s) => s.day), today),
    weekly,
    muscleDistribution: muscleDistribution(inWindow, metaById),
    heatmap: [...heatmapByDay.values()].map((d) => ({ ...d, volume: Math.round(d.volume) })),
    lastWorkoutAt: sessions.length ? sessions[sessions.length - 1].startedAt : null,
    daysSinceLastWorkout: sessions.length ? daysBetween(withDay[withDay.length - 1].day, today) : null,
  };
}

/**
 * Per-session history of one exercise (best e1RM, top set, volume), newest
 * first and paginated, plus all-time bests from the PR table.
 */
export async function exerciseHistory(userId, exerciseId, { page, limit }) {
  const exercise = await Exercise.findOne({
    _id: exerciseId,
    $or: [{ createdBy: null }, { createdBy: userId }],
  }).select('name isBodyweight images');
  if (!exercise) throw AppError.notFound('Exercise');

  const filter = { userId, status: 'completed', 'exercises.exerciseId': exercise._id };
  const [sessions, total, records] = await Promise.all([
    WorkoutSession.find(filter)
      .sort({ startedAt: -1 })
      .skip((page - 1) * limit)
      .limit(limit)
      .select('startedAt bodyweightKg exercises')
      .lean(),
    WorkoutSession.countDocuments(filter),
    PersonalRecord.find({ userId, exerciseId: exercise._id }).sort({ value: -1 }).lean(),
  ]);

  const data = sessions.map((s) => {
    const sets = s.exercises
      .filter((e) => e.exerciseId.toString() === exercise._id.toString())
      .flatMap((e) => e.sets)
      .filter((set) => set.completed && QUALIFYING_SET_TYPES.includes(set.type));
    let bestE1rm = null;
    let topSet = null;
    let volume = 0;
    for (const set of sets) {
      const e = setE1rm(set, exercise, s.bodyweightKg);
      if (e && (bestE1rm === null || e > bestE1rm)) bestE1rm = e;
      if (!topSet || set.weight > topSet.weight || (set.weight === topSet.weight && set.reps > topSet.reps)) {
        topSet = { weight: set.weight, reps: set.reps };
      }
      if (set.weight > 0) volume += set.weight * set.reps;
    }
    return {
      sessionId: s._id.toString(),
      date: s.startedAt,
      bestE1rm,
      topSet,
      sets: sets.length,
      volume: Math.round(volume * 10) / 10,
    };
  });

  const bestOf = (type) => records.find((r) => r.type === type) ?? null;
  const pick = (r) => (r ? { value: r.value, weight: r.weight, reps: r.reps, achievedAt: r.achievedAt } : null);

  return {
    exercise: { id: exercise._id.toString(), name: exercise.name, image: exercise.images?.[0] ?? null },
    bests: {
      e1rm: pick(bestOf('e1rm')),
      maxWeight: pick(bestOf('maxWeight')),
      maxVolumeSet: pick(bestOf('maxVolumeSet')),
    },
    data,
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit)),
  };
}
