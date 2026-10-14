import { bestsFromRecords, evaluateSession, sessionBestsForExercise } from '../../src/services/prService.js';

const BENCH = 'bench';
const PULLUP = 'pullup';
const meta = new Map([
  [BENCH, { isBodyweight: false }],
  [PULLUP, { isBodyweight: true }],
]);

const set = (weight, reps, extra = {}) => ({ weight, reps, type: 'working', completed: true, ...extra });
const session = (exerciseId, sets, bodyweightKg = 80) => ({ bodyweightKg, exercises: [{ exerciseId, sets }] });
const real = (records) => records.filter((r) => !r.isBaseline);

describe('sessionBestsForExercise', () => {
  it('ignores warm-ups, drop sets and incomplete sets', () => {
    const sb = sessionBestsForExercise(
      [
        set(140, 1, { type: 'warmup' }),
        set(130, 3, { type: 'dropset' }),
        set(150, 1, { completed: false }),
        set(100, 5),
      ],
      meta.get(BENCH),
      80,
    );
    expect(sb.maxWeight.value).toBe(100);
    expect(sb.e1rm.value).toBe(116.7);
  });

  it('counts failure sets as working sets', () => {
    const sb = sessionBestsForExercise([set(110, 3, { type: 'failure' })], meta.get(BENCH), 80);
    expect(sb.maxWeight.value).toBe(110);
  });

  it('excludes >12-rep sets from e1RM but keeps them for volume and reps', () => {
    const sb = sessionBestsForExercise([set(50, 20)], meta.get(BENCH), 80);
    expect(sb.e1rm).toBeNull();
    expect(sb.maxVolumeSet.value).toBe(1000);
    expect(sb.repsAtWeight.get('50.00').value).toBe(20);
  });
});

describe('evaluateSession', () => {
  it('records baselines on the first session, without celebrating them', () => {
    const bests = new Map();
    const records = evaluateSession(session(BENCH, [set(100, 5), set(100, 4)]), meta, bests);
    expect(records.every((r) => r.isBaseline)).toBe(true);
    expect(records.map((r) => r.type).sort()).toEqual(['e1rm', 'maxRepsAtWeight', 'maxVolumeSet', 'maxWeight']);
  });

  it('detects each PR type against history', () => {
    const bests = new Map();
    evaluateSession(session(BENCH, [set(100, 5)]), meta, bests);

    // Heavier single: a weight PR, but its e1RM (105) is below 116.7 and volume is lower
    let prs = real(evaluateSession(session(BENCH, [set(105, 1)]), meta, bests));
    expect(prs.map((p) => p.type)).toEqual(['maxWeight']);
    expect(prs[0]).toMatchObject({ value: 105, previousValue: 100 });

    // More reps at 100 kg → reps PR, e1RM PR and volume PR
    prs = real(evaluateSession(session(BENCH, [set(100, 7)]), meta, bests));
    expect(prs.map((p) => p.type).sort()).toEqual(['e1rm', 'maxRepsAtWeight', 'maxVolumeSet']);
    expect(prs.find((p) => p.type === 'maxRepsAtWeight')).toMatchObject({ value: 7, weight: 100, previousValue: 5 });
  });

  it('does not report a PR for equal performance', () => {
    const bests = new Map();
    evaluateSession(session(BENCH, [set(100, 5)]), meta, bests);
    expect(evaluateSession(session(BENCH, [set(100, 5)]), meta, bests)).toEqual([]);
  });

  it('reports one PR per type per session (its best set)', () => {
    const bests = new Map();
    evaluateSession(session(BENCH, [set(100, 5)]), meta, bests);
    const prs = real(evaluateSession(session(BENCH, [set(102.5, 5), set(105, 5), set(107.5, 3)]), meta, bests));
    for (const type of ['maxWeight', 'e1rm', 'maxVolumeSet']) {
      expect(prs.filter((p) => p.type === type)).toHaveLength(1);
    }
    expect(prs.find((p) => p.type === 'maxWeight').value).toBe(107.5);
    expect(prs.find((p) => p.type === 'e1rm').value).toBe(122.5); // 105 × (1 + 5/30)
    expect(prs.find((p) => p.type === 'maxVolumeSet').value).toBe(525); // 105 × 5
  });

  it('treats a first time at a new weight as a baseline, not a reps PR', () => {
    const bests = new Map();
    evaluateSession(session(BENCH, [set(100, 5)]), meta, bests);
    const records = evaluateSession(session(BENCH, [set(90, 8)]), meta, bests);
    const reps = records.find((r) => r.type === 'maxRepsAtWeight');
    expect(reps).toMatchObject({ weight: 90, isBaseline: true });
  });

  it('merges sets when an exercise appears twice in a session', () => {
    const bests = new Map();
    evaluateSession(session(BENCH, [set(100, 5)]), meta, bests);
    const s = { bodyweightKg: 80, exercises: [{ exerciseId: BENCH, sets: [set(100, 3)] }, { exerciseId: BENCH, sets: [set(110, 2)] }] };
    const prs = real(evaluateSession(s, meta, bests));
    expect(prs.filter((p) => p.type === 'maxWeight')).toEqual([expect.objectContaining({ value: 110 })]);
  });

  it('handles bodyweight exercises: reps at bodyweight and e1RM with bodyweight', () => {
    const bests = new Map();
    evaluateSession(session(PULLUP, [set(0, 8)], 80), meta, bests);
    const prs = real(evaluateSession(session(PULLUP, [set(0, 10)], 80), meta, bests));
    expect(prs.find((p) => p.type === 'maxRepsAtWeight')).toMatchObject({ weight: 0, value: 10, previousValue: 8 });
    expect(prs.find((p) => p.type === 'e1rm')).toMatchObject({ value: 106.7 });
    // No weight-based records for unweighted reps
    expect(prs.some((p) => p.type === 'maxWeight')).toBe(false);
  });

  it('can be limited to specific exercises', () => {
    const bests = new Map();
    const s = { bodyweightKg: 80, exercises: [{ exerciseId: BENCH, sets: [set(100, 5)] }, { exerciseId: PULLUP, sets: [set(0, 5)] }] };
    const records = evaluateSession(s, meta, bests, { onlyExerciseIds: new Set([PULLUP]) });
    expect(new Set(records.map((r) => r.exerciseId))).toEqual(new Set([PULLUP]));
  });
});

describe('bestsFromRecords', () => {
  it('rebuilds bests (including per-weight reps) from stored records', () => {
    const bests = bestsFromRecords([
      { exerciseId: BENCH, type: 'maxWeight', value: 100 },
      { exerciseId: BENCH, type: 'maxWeight', value: 105 },
      { exerciseId: BENCH, type: 'maxRepsAtWeight', value: 5, weight: 100 },
      { exerciseId: BENCH, type: 'maxRepsAtWeight', value: 7, weight: 100.0001 },
    ]);
    const b = bests.get(BENCH);
    expect(b.maxWeight).toBe(105);
    expect(b.repsAtWeight.get('100.00')).toBe(7);
    // Continuing from stored bests behaves like continuing in memory
    const prs = real(evaluateSession(session(BENCH, [set(100, 8)]), meta, bests));
    expect(prs.find((p) => p.type === 'maxRepsAtWeight')).toMatchObject({ value: 8, previousValue: 7 });
  });
});
