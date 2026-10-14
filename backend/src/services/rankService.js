import { readFileSync } from 'node:fs';
import { MUSCLE_GROUPS, RANKED_LIFTS } from '../config/lifts.js';
import { Exercise } from '../models/Exercise.js';
import { User } from '../models/User.js';
import { WorkoutSession } from '../models/WorkoutSession.js';
import { AppError } from '../utils/AppError.js';
import { QUALIFYING_SET_TYPES } from './prService.js';
import { setE1rm } from './oneRepMax.js';

export const STANDARDS = JSON.parse(
  readFileSync(new URL('../config/strengthStandards.json', import.meta.url), 'utf8'),
);
export const TIERS = STANDARDS.tiers;

/** Ranks reflect current strength: only lifts from this many days back count. */
export const RANK_WINDOW_DAYS = 365;

const round = (n, dp = 2) => Math.round(n * 10 ** dp) / 10 ** dp;

/**
 * Places a bodyweight ratio within a lift's tier thresholds.
 * @param {number} ratio  e1RM ÷ bodyweight
 * @param {number[]} thresholds  ascending entry ratios, one per tier
 */
export function tierFor(ratio, thresholds) {
  let index = 0;
  for (let i = thresholds.length - 1; i >= 0; i -= 1) {
    if (ratio >= thresholds[i]) {
      index = i;
      break;
    }
  }
  const isMax = index === thresholds.length - 1;
  const lo = thresholds[index];
  const hi = isMax ? null : thresholds[index + 1];
  const progress = isMax ? 100 : Math.round(Math.min(1, Math.max(0, (ratio - lo) / (hi - lo))) * 100);
  return {
    tierIndex: index,
    tier: TIERS[index],
    nextTier: isMax ? null : TIERS[index + 1],
    progress,
    nextThreshold: hi,
  };
}

/** Continuous score 0–7 (tier index + progress fraction) used for averaging. */
export const scoreOf = ({ tierIndex, progress }) => tierIndex + (tierIndex === TIERS.length - 1 ? 0 : progress / 100);

/** Turns an averaged score back into a tier + progress toward the next. */
export function fromScore(score) {
  const max = TIERS.length - 1;
  const clamped = Math.min(max, Math.max(0, score));
  const tierIndex = Math.min(max, Math.floor(clamped));
  const progress = tierIndex === max ? 100 : Math.round((clamped - tierIndex) * 100);
  return {
    tierIndex,
    tier: TIERS[tierIndex],
    nextTier: tierIndex === max ? null : TIERS[tierIndex + 1],
    progress,
    score: round(clamped),
  };
}

function weightedAverage(entries) {
  const total = entries.reduce((s, e) => s + e.weight, 0);
  if (!total) return null;
  return entries.reduce((s, e) => s + e.score * e.weight, 0) / total;
}

/**
 * Computes per-lift, per-muscle-group and overall ranks.
 *
 * @param {{ sex: 'male'|'female'|null, bestByLift: Record<string, { e1rm:number, bodyweightKg:number, achievedAt?:Date, exerciseId?:any }> }} input
 */
export function computeRanks({ sex, bestByLift }) {
  const standardsSex = sex === 'female' ? 'female' : 'male';

  const lifts = Object.entries(RANKED_LIFTS).map(([key, lift]) => {
    const best = bestByLift[key];
    const thresholds = STANDARDS.lifts[key][standardsSex];
    if (!best || !(best.bodyweightKg > 0)) {
      return { key, name: lift.name, ranked: false, thresholds };
    }
    const ratio = best.e1rm / best.bodyweightKg;
    const t = tierFor(ratio, thresholds);
    return {
      key,
      name: lift.name,
      ranked: true,
      ratio: round(ratio),
      e1rm: best.e1rm,
      bodyweightKg: best.bodyweightKg,
      achievedAt: best.achievedAt ?? null,
      exerciseId: best.exerciseId ?? null,
      // e1RM (kg) needed to reach the next tier at the bodyweight of this lift.
      nextTierE1rm: t.nextThreshold === null ? null : round(t.nextThreshold * best.bodyweightKg, 1),
      thresholds,
      ...t,
      score: round(scoreOf(t)),
    };
  });

  const ranked = lifts.filter((l) => l.ranked);
  const scoreByLift = Object.fromEntries(ranked.map((l) => [l.key, l.score]));

  const muscleGroups = Object.keys(MUSCLE_GROUPS).map((group) => {
    const contributions = Object.entries(RANKED_LIFTS)
      .filter(([key, lift]) => lift.muscleGroups[group] && scoreByLift[key] !== undefined)
      .map(([key, lift]) => ({ score: scoreByLift[key], weight: lift.muscleGroups[group] }));
    const avg = weightedAverage(contributions);
    return avg === null ? { group, ranked: false } : { group, ranked: true, ...fromScore(avg) };
  });

  const overallAvg = weightedAverage(
    ranked.map((l) => ({ score: l.score, weight: STANDARDS.overallWeights[l.key] ?? 0 })),
  );
  const overall =
    overallAvg === null
      ? { ranked: false, liftsRanked: 0 }
      : { ranked: true, liftsRanked: ranked.length, ...fromScore(overallAvg) };

  return { sex: standardsSex, assumedSex: !sex, tiers: TIERS, overall, lifts, muscleGroups };
}

/**
 * Best e1RM ÷ bodyweight per ranked lift over the rank window, read from the
 * user's completed sessions (each session carries its bodyweight snapshot).
 */
export async function bestLiftsForUser(userId, { now = new Date(), fallbackBodyweightKg = null } = {}) {
  const liftExercises = await Exercise.find({ liftKey: { $ne: null }, createdBy: null }).select(
    '_id liftKey isBodyweight',
  );
  const byId = new Map(liftExercises.map((e) => [e._id.toString(), e]));
  if (!byId.size) return {};

  const since = new Date(now.getTime() - RANK_WINDOW_DAYS * 24 * 3600 * 1000);
  const sessions = await WorkoutSession.find({
    userId,
    status: 'completed',
    startedAt: { $gte: since },
    'exercises.exerciseId': { $in: [...byId.keys()] },
  })
    .select('startedAt endedAt bodyweightKg exercises')
    .lean();

  const best = {};
  for (const session of sessions) {
    const bw = session.bodyweightKg || fallbackBodyweightKg;
    if (!(bw > 0)) continue;
    for (const ex of session.exercises) {
      const meta = byId.get(ex.exerciseId.toString());
      if (!meta) continue;
      for (const set of ex.sets) {
        if (!set.completed || !QUALIFYING_SET_TYPES.includes(set.type)) continue;
        const e1rm = setE1rm(set, meta, bw);
        if (!e1rm) continue;
        const ratio = e1rm / bw;
        const current = best[meta.liftKey];
        if (!current || ratio > current.e1rm / current.bodyweightKg) {
          best[meta.liftKey] = {
            e1rm,
            bodyweightKg: bw,
            achievedAt: session.endedAt ?? session.startedAt,
            exerciseId: meta._id,
          };
        }
      }
    }
  }
  return best;
}

export async function ranksForUser(userId) {
  const user = await User.findById(userId);
  if (!user) throw AppError.notFound('User');
  const bestByLift = await bestLiftsForUser(userId, { fallbackBodyweightKg: user.bodyweightKg });
  return { user, ranks: computeRanks({ sex: user.sex, bestByLift }) };
}

/**
 * Compares current tiers with the snapshot stored on the user, saves the new
 * snapshot and returns the changes (for level-up / level-down animations).
 */
export function diffRankSnapshot(previous = {}, ranks) {
  const current = { overall: ranks.overall.ranked ? ranks.overall.tierIndex : null };
  for (const l of ranks.lifts) current[l.key] = l.ranked ? l.tierIndex : null;

  const changes = [];
  for (const [key, to] of Object.entries(current)) {
    const from = previous?.[key] ?? null;
    if (to !== null && to !== from) {
      changes.push({
        key,
        name: key === 'overall' ? 'Overall' : RANKED_LIFTS[key].name,
        from: from === null ? null : TIERS[from],
        to: TIERS[to],
        direction: from === null || to > from ? 'up' : 'down',
      });
    }
  }
  return { snapshot: current, changes };
}

export async function refreshRanksAndDiff(userId) {
  const { user, ranks } = await ranksForUser(userId);
  const { snapshot, changes } = diffRankSnapshot(user.rankTiers, ranks);
  user.rankTiers = snapshot;
  user.markModified('rankTiers');
  await user.save();
  return { ranks, changes };
}
