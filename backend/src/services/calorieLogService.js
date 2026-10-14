import { CalorieLog } from '../models/CalorieLog.js';
import { User } from '../models/User.js';
import { WorkoutSession } from '../models/WorkoutSession.js';
import { AppError } from '../utils/AppError.js';
import { localDay, utcWindowForDays } from '../utils/dates.js';
import { paginate } from '../utils/pagination.js';
import { calculateTargets } from './tdeeService.js';

export function totalsOf(entries) {
  const t = { kcal: 0, protein: 0, carbs: 0, fat: 0 };
  for (const e of entries ?? []) {
    t.kcal += e.kcal || 0;
    t.protein += e.protein || 0;
    t.carbs += e.carbs || 0;
    t.fat += e.fat || 0;
  }
  for (const k of Object.keys(t)) t[k] = Math.round(t[k] * 10) / 10;
  return t;
}

/** The user's manual target, or the TDEE recommendation for their goal (null if profile incomplete). */
export function effectiveTarget(user) {
  if (user.calorieTargetKcal) return user.calorieTargetKcal;
  try {
    return calculateTargets(user).recommendedKcal;
  } catch {
    return null;
  }
}

/** kcal burned by completed workouts that started on a local calendar day. */
export async function burnedOnDay(userId, day, tz) {
  const sessions = await WorkoutSession.find({
    userId,
    status: 'completed',
    startedAt: utcWindowForDays(day, day),
  })
    .select('startedAt caloriesBurned name durationSec')
    .lean();
  const today = sessions.filter((s) => localDay(s.startedAt, tz) === day);
  return {
    kcal: today.reduce((sum, s) => sum + (s.caloriesBurned || 0), 0),
    workouts: today.map((s) => ({
      id: s._id.toString(),
      name: s.name,
      kcal: s.caloriesBurned,
      durationSec: s.durationSec,
    })),
  };
}

function dayView(log, { date, targetKcal, burned }) {
  const entries = log?.entries ?? [];
  const consumed = totalsOf(entries);
  const target = log?.targetKcal ?? targetKcal;
  return {
    date,
    entries: entries.map((e) => ({
      id: e._id.toString(),
      name: e.name,
      kcal: e.kcal,
      protein: e.protein,
      carbs: e.carbs,
      fat: e.fat,
      loggedAt: e.loggedAt,
    })),
    consumed,
    targetKcal: target,
    burned,
    /** Target minus food plus workout calories (estimate). */
    remainingKcal: target == null ? null : Math.round(target - consumed.kcal + burned.kcal),
  };
}

export async function getDay(userId, date, tz) {
  const user = await User.findById(userId);
  if (!user) throw AppError.notFound('User');
  const [log, burned] = await Promise.all([CalorieLog.findOne({ userId, date }), burnedOnDay(userId, date, tz)]);
  return dayView(log, { date, targetKcal: effectiveTarget(user), burned });
}

export async function listDays(userId, { from, to, page, limit }) {
  const filter = { userId };
  if (from || to) {
    filter.date = {};
    if (from) filter.date.$gte = from;
    if (to) filter.date.$lte = to;
  }
  const result = await paginate(CalorieLog, filter, { page, limit, sort: { date: -1 } });
  return {
    ...result,
    data: result.data.map((log) => ({
      date: log.date,
      targetKcal: log.targetKcal,
      consumed: totalsOf(log.entries),
      entryCount: log.entries.length,
    })),
  };
}

export async function addEntry(userId, { date, tz, ...entry }) {
  const user = await User.findById(userId);
  if (!user) throw AppError.notFound('User');
  const log = await CalorieLog.findOneAndUpdate(
    { userId, date },
    { $push: { entries: entry }, $setOnInsert: { userId, date, targetKcal: effectiveTarget(user) } },
    { upsert: true, new: true, runValidators: true },
  );
  const burned = await burnedOnDay(userId, date, tz);
  return dayView(log, { date, targetKcal: effectiveTarget(user), burned });
}

export async function deleteEntry(userId, entryId) {
  const res = await CalorieLog.updateOne({ userId, 'entries._id': entryId }, { $pull: { entries: { _id: entryId } } });
  if (!res.modifiedCount) throw AppError.notFound('Calorie entry');
}

export async function getTarget(userId) {
  const user = await User.findById(userId);
  if (!user) throw AppError.notFound('User');
  let breakdown = null;
  let missing = [];
  try {
    breakdown = calculateTargets(user);
  } catch (err) {
    if (err.code !== 'PROFILE_INCOMPLETE') throw err;
    missing = err.details.missing;
  }
  return {
    customTargetKcal: user.calorieTargetKcal,
    effectiveTargetKcal: effectiveTarget(user),
    goal: user.goal,
    tdee: breakdown,
    profileIncomplete: missing.length > 0,
    missing,
  };
}

/**
 * Sets a manual target (or clears it with null) and/or changes the goal.
 * When `date` is given, that day's log adopts the new target too.
 */
export async function setTarget(userId, { targetKcal, goal, date }) {
  const user = await User.findById(userId);
  if (!user) throw AppError.notFound('User');
  if (targetKcal !== undefined) user.calorieTargetKcal = targetKcal;
  if (goal) user.goal = goal;
  await user.save();
  if (date) {
    await CalorieLog.updateOne({ userId, date }, { $set: { targetKcal: effectiveTarget(user) } });
  }
  return getTarget(userId);
}
