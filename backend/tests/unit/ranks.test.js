import {
  computeRanks,
  diffRankSnapshot,
  fromScore,
  STANDARDS,
  TIERS,
  tierFor,
} from '../../src/services/rankService.js';

const benchMale = STANDARDS.lifts.bench_press.male; // [0, .6, .85, 1.1, 1.35, 1.6, 2.0]

describe('strength standards file', () => {
  it('covers every required lift for both sexes with ascending thresholds', () => {
    for (const lift of ['bench_press', 'squat', 'deadlift', 'overhead_press', 'barbell_row', 'pull_up', 'dips']) {
      for (const sex of ['male', 'female']) {
        const t = STANDARDS.lifts[lift][sex];
        expect(t).toHaveLength(TIERS.length);
        expect(t[0]).toBe(0);
        for (let i = 1; i < t.length; i += 1) expect(t[i]).toBeGreaterThan(t[i - 1]);
      }
    }
    expect(TIERS).toEqual(['Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Elite', 'Legend']);
  });
});

describe('tierFor', () => {
  it('places a ratio in its tier with progress to the next', () => {
    expect(tierFor(1.0, benchMale)).toMatchObject({ tier: 'Gold', nextTier: 'Platinum', progress: 60 });
    expect(tierFor(0.6, benchMale)).toMatchObject({ tier: 'Silver', progress: 0 });
    expect(tierFor(0.3, benchMale)).toMatchObject({ tier: 'Bronze', progress: 50 });
  });

  it('caps at Legend with 100% progress', () => {
    expect(tierFor(2.5, benchMale)).toMatchObject({ tier: 'Legend', nextTier: null, progress: 100 });
  });
});

describe('fromScore', () => {
  it('converts an averaged score into tier + progress', () => {
    expect(fromScore(2.25)).toMatchObject({ tier: 'Gold', progress: 25 });
    expect(fromScore(9)).toMatchObject({ tier: 'Legend', progress: 100 });
    expect(fromScore(-1)).toMatchObject({ tier: 'Bronze', progress: 0 });
  });
});

describe('computeRanks', () => {
  it('ranks by e1RM ÷ bodyweight with sex-specific thresholds', () => {
    const best = { bench_press: { e1rm: 80, bodyweightKg: 80 } }; // ratio 1.0
    const male = computeRanks({ sex: 'male', bestByLift: best });
    const female = computeRanks({ sex: 'female', bestByLift: best });
    expect(male.lifts.find((l) => l.key === 'bench_press')).toMatchObject({ tier: 'Gold', ratio: 1 });
    expect(female.lifts.find((l) => l.key === 'bench_press')).toMatchObject({ tier: 'Diamond' });
  });

  it('reports the e1RM needed for the next tier', () => {
    const r = computeRanks({ sex: 'male', bestByLift: { squat: { e1rm: 100, bodyweightKg: 80 } } }); // 1.25
    const squat = r.lifts.find((l) => l.key === 'squat');
    expect(squat).toMatchObject({ tier: 'Gold', nextTier: 'Platinum', nextTierE1rm: 120 });
  });

  it('leaves lifts without data unranked and excludes them from averages', () => {
    const r = computeRanks({ sex: 'male', bestByLift: { bench_press: { e1rm: 80, bodyweightKg: 80 } } });
    expect(r.lifts.filter((l) => l.ranked)).toHaveLength(1);
    expect(r.overall).toMatchObject({ ranked: true, liftsRanked: 1, tier: 'Gold', progress: 60 });
    expect(r.muscleGroups.find((g) => g.group === 'legs')).toEqual({ group: 'legs', ranked: false });
    expect(r.muscleGroups.find((g) => g.group === 'chest')).toMatchObject({ ranked: true, tier: 'Gold' });
  });

  it('computes the overall rank as a weighted average', () => {
    // squat: ratio 2.75 → Legend (score 6); bench ratio 0.3 → Bronze 50% (score 0.5)
    const r = computeRanks({
      sex: 'male',
      bestByLift: { squat: { e1rm: 220, bodyweightKg: 80 }, bench_press: { e1rm: 24, bodyweightKg: 80 } },
    });
    // equal 0.2 weights → (6 + 0.5) / 2 = 3.25 → Platinum 25%
    expect(r.overall).toMatchObject({ tier: 'Platinum', progress: 25 });
  });

  it('ranks bodyweight lifts including bodyweight', () => {
    // 80 kg lifter, 10 strict pull-ups → e1RM 80 × 1.333 = 106.7 → ratio 1.33 → Platinum
    const r = computeRanks({ sex: 'male', bestByLift: { pull_up: { e1rm: 106.7, bodyweightKg: 80 } } });
    expect(r.lifts.find((l) => l.key === 'pull_up')).toMatchObject({ tier: 'Platinum' });
  });

  it('assumes male standards when sex is unknown and says so', () => {
    const r = computeRanks({ sex: null, bestByLift: {} });
    expect(r).toMatchObject({ sex: 'male', assumedSex: true, overall: { ranked: false } });
  });
});

describe('diffRankSnapshot', () => {
  const ranksWith = (benchTier, overallTier) => ({
    overall: { ranked: true, tierIndex: overallTier },
    lifts: [
      { key: 'bench_press', ranked: true, tierIndex: benchTier },
      { key: 'squat', ranked: false },
    ],
  });

  it('reports first ranks and level-ups', () => {
    const first = diffRankSnapshot({}, ranksWith(2, 2));
    expect(first.changes.map((c) => [c.key, c.from, c.to, c.direction])).toEqual([
      ['overall', null, 'Gold', 'up'],
      ['bench_press', null, 'Gold', 'up'],
    ]);
    const next = diffRankSnapshot(first.snapshot, ranksWith(3, 2));
    expect(next.changes).toEqual([
      { key: 'bench_press', name: 'Bench Press', from: 'Gold', to: 'Platinum', direction: 'up' },
    ]);
  });

  it('reports nothing when tiers are unchanged', () => {
    const { snapshot } = diffRankSnapshot({}, ranksWith(2, 2));
    expect(diffRankSnapshot(snapshot, ranksWith(2, 2)).changes).toEqual([]);
  });
});
