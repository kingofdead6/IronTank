import request from 'supertest';
import { createApp } from '../../src/app.js';
import { PersonalRecord } from '../../src/models/PersonalRecord.js';
import { WorkoutSession } from '../../src/models/WorkoutSession.js';
import { registerUser } from '../helpers/auth.js';
import { clearDb, setupTestDb, teardownTestDb } from '../helpers/db.js';
import { seedSampleExercises } from '../helpers/fixtures.js';

const app = createApp();
const api = '/api/v1';
let ex;
let seq = 0;

beforeAll(setupTestDb);
beforeEach(async () => {
  ex = await seedSampleExercises();
});
afterEach(clearDb);
afterAll(teardownTestDb);

const HOUR = 3600e3;
const set = (weight, reps, extra = {}) => ({ weight, reps, completed: true, type: 'working', ...extra });

/** Builds a finished-workout payload `daysAgo` days in the past. */
function workout(exercises, { daysAgo = 0, hours = 1, ...rest } = {}) {
  seq += 1;
  const startedAt = new Date(Date.now() - daysAgo * 24 * HOUR - hours * HOUR - 60e3);
  return {
    clientId: `client-${seq}-${Date.now()}`,
    name: 'Session',
    startedAt: startedAt.toISOString(),
    endedAt: new Date(startedAt.getTime() + hours * HOUR).toISOString(),
    exercises,
    ...rest,
  };
}

const bench = (sets) => ({ exerciseId: ex['Barbell_Bench_Press_-_Medium_Grip'].id, sets });

async function lifter(profile = { sex: 'male', bodyweightKg: 80, heightCm: 180, birthDate: '1995-01-01' }) {
  const u = await registerUser(app);
  await request(app).patch(`${api}/users/me`).set(u.auth).send(profile).expect(200);
  return u;
}

describe('POST /workouts', () => {
  it('saves a session with derived volume, duration and calories', async () => {
    const { auth } = await lifter();
    const body = workout(
      [bench([set(60, 10, { type: 'warmup' }), set(100, 5), set(100, 5), set(100, 4, { completed: false })])],
      { activeDurationSec: 2700 },
    );
    const res = await request(app).post(`${api}/workouts`).set(auth).send(body);

    expect(res.status).toBe(201);
    const { session, calories } = res.body;
    expect(session).toMatchObject({ status: 'completed', durationSec: 3600, activeDurationSec: 2700, totalVolume: 1000, bodyweightKg: 80 });
    expect(session.exercises[0].exerciseName).toBe('Barbell Bench Press - Medium Grip');
    // Barbell MET 6 × 80 kg × 0.75 h
    expect(calories).toEqual({ kcal: 360, isEstimate: true, usedDefaultBodyweight: false });
    expect(session.caloriesBurned).toBe(360);
  });

  it('is idempotent on clientId (offline retry safe)', async () => {
    const { auth } = await lifter();
    const body = workout([bench([set(100, 5)])]);
    const first = await request(app).post(`${api}/workouts`).set(auth).send(body);
    const retry = await request(app).post(`${api}/workouts`).set(auth).send(body);
    expect(first.status).toBe(201);
    expect(retry.status).toBe(200);
    expect(retry.body.session.id).toBe(first.body.session.id);
    expect(await WorkoutSession.countDocuments()).toBe(1);
  });

  it('rejects unknown exercises, future dates and negative loads on barbell lifts', async () => {
    const { auth } = await lifter();
    const unknown = workout([{ exerciseId: '0123456789abcdef01234567', sets: [] }]);
    expect((await request(app).post(`${api}/workouts`).set(auth).send(unknown)).body.error.code).toBe('UNKNOWN_EXERCISE');

    const future = workout([], { daysAgo: -2 });
    expect((await request(app).post(`${api}/workouts`).set(auth).send(future)).status).toBe(422);

    const negative = workout([bench([set(-10, 5)])]);
    expect((await request(app).post(`${api}/workouts`).set(auth).send(negative)).body.error.code).toBe('INVALID_WEIGHT');

    const assisted = workout([{ exerciseId: ex.Pullups.id, sets: [set(-20, 8)] }]);
    expect((await request(app).post(`${api}/workouts`).set(auth).send(assisted)).status).toBe(201);
  });
});

describe('PR detection on save', () => {
  it('stores baselines silently, then returns real PRs', async () => {
    const { auth } = await lifter();
    const first = await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(100, 5)])], { daysAgo: 7 }));
    expect(first.body.newPRs).toEqual([]);
    expect(await PersonalRecord.countDocuments({ isBaseline: true })).toBe(4);

    const second = await request(app)
      .post(`${api}/workouts`)
      .set(auth)
      .send(workout([bench([set(105, 5)])], { daysAgo: 3 }));
    const types = second.body.newPRs.map((p) => p.type).sort();
    expect(types).toEqual(['e1rm', 'maxVolumeSet', 'maxWeight']);
    expect(second.body.newPRs.find((p) => p.type === 'maxWeight')).toMatchObject({
      value: 105,
      previousValue: 100,
      exerciseName: 'Barbell Bench Press - Medium Grip',
    });
    expect(second.body.session.prCount).toBe(3);
  });

  it('replays history for a backdated session', async () => {
    const { auth } = await lifter();
    await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(100, 5)])], { daysAgo: 1 }));
    // Logged later but happened earlier, and heavier: it becomes the baseline,
    // and the newer 100 kg session is no longer a record.
    const back = await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(110, 5)])], { daysAgo: 10 }));
    expect(back.body.newPRs).toEqual([]);
    const weightRecords = await PersonalRecord.find({ type: 'maxWeight' }).sort({ achievedAt: 1 });
    expect(weightRecords.map((r) => r.value)).toEqual([110]);
  });

  it('rebuilds records when a workout is edited or deleted', async () => {
    const { auth } = await lifter();
    await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(100, 5)])], { daysAgo: 5 }));
    const { body } = await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(120, 3)])], { daysAgo: 2 }));
    const id = body.session.id;

    // Fix a typo: 120 was really 102.5
    const edited = await request(app).patch(`${api}/workouts/${id}`).set(auth).send({ exercises: [bench([set(102.5, 3)])] });
    expect(edited.status).toBe(200);
    expect(edited.body.session.totalVolume).toBe(307.5);
    const best = await PersonalRecord.find({ type: 'maxWeight' }).sort({ value: -1 });
    expect(best[0].value).toBe(102.5);

    await request(app).delete(`${api}/workouts/${id}`).set(auth).expect(204);
    const after = await PersonalRecord.find({ type: 'maxWeight' });
    expect(after.map((r) => r.value)).toEqual([100]);
  });
});

describe('PR endpoints', () => {
  it('lists celebrated PRs and per-exercise bests', async () => {
    const { auth } = await lifter();
    await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(100, 5)])], { daysAgo: 4 }));
    await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(100, 8)])], { daysAgo: 2 }));

    const list = await request(app).get(`${api}/prs`).set(auth);
    expect(list.body.data.every((r) => r.isBaseline === false)).toBe(true);
    expect(list.body.data[0].exercise.name).toBe('Barbell Bench Press - Medium Grip');

    const withBaselines = await request(app).get(`${api}/prs?includeBaselines=true`).set(auth);
    expect(withBaselines.body.total).toBeGreaterThan(list.body.total);

    const one = await request(app).get(`${api}/prs/${ex['Barbell_Bench_Press_-_Medium_Grip'].id}`).set(auth);
    expect(one.body.current).toMatchObject({
      maxWeight: { value: 100 },
      e1rm: { value: 126.7 },
      maxVolumeSet: { value: 800 },
      repsAtWeight: [{ weight: 100, reps: 8 }],
    });
    expect(one.body.history.total).toBeGreaterThan(0);
  });
});

describe('ranks', () => {
  it('ranks lifts from saved sessions and reports level-ups', async () => {
    const { auth } = await lifter();
    // 80 kg male, bench e1RM 80 → ratio 1.0 → Gold
    const first = await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(80, 1)])], { daysAgo: 3 }));
    expect(first.body.rankChanges).toEqual(
      expect.arrayContaining([expect.objectContaining({ key: 'bench_press', from: null, to: 'Gold', direction: 'up' })]),
    );

    // e1RM 90 → 1.125 → Platinum
    const second = await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(90, 1)])], { daysAgo: 1 }));
    expect(second.body.rankChanges).toEqual(
      expect.arrayContaining([expect.objectContaining({ key: 'bench_press', from: 'Gold', to: 'Platinum' })]),
    );

    const ranks = await request(app).get(`${api}/ranks`).set(auth);
    expect(ranks.status).toBe(200);
    const benchRank = ranks.body.lifts.find((l) => l.key === 'bench_press');
    expect(benchRank).toMatchObject({ tier: 'Platinum', ranked: true, ratio: 1.13 });
    expect(benchRank.progress).toBeGreaterThan(0);
    expect(ranks.body.overall).toMatchObject({ ranked: true, tier: 'Platinum' });
    expect(ranks.body.muscleGroups.find((g) => g.group === 'chest')).toMatchObject({ ranked: true });
  });

  it('ranks pull-ups on bodyweight plus added load', async () => {
    const { auth } = await lifter();
    // 10 bodyweight reps → e1RM 106.7 → ratio 1.33 → Platinum
    await request(app).post(`${api}/workouts`).set(auth).send(workout([{ exerciseId: ex.Pullups.id, sets: [set(0, 10)] }]));
    const ranks = await request(app).get(`${api}/ranks`).set(auth);
    expect(ranks.body.lifts.find((l) => l.key === 'pull_up')).toMatchObject({ tier: 'Platinum', e1rm: 106.7 });
  });
});

describe('active workout draft', () => {
  it('upserts, returns and discards the in-progress session', async () => {
    const { auth } = await lifter();
    const draft = {
      clientId: 'draft-123456',
      startedAt: new Date().toISOString(),
      exercises: [bench([set(100, 5), { weight: 100, reps: 0 }])],
    };
    const put = await request(app).put(`${api}/workouts/active`).set(auth).send(draft);
    expect(put.status).toBe(200);
    expect(put.body.session).toMatchObject({ status: 'active', clientId: 'draft-123456' });

    // Updating replaces the same draft
    await request(app).put(`${api}/workouts/active`).set(auth).send({ ...draft, notes: 'felt good' }).expect(200);
    const get = await request(app).get(`${api}/workouts/active`).set(auth);
    expect(get.body.session.notes).toBe('felt good');
    expect(await WorkoutSession.countDocuments({ status: 'active' })).toBe(1);

    // Drafts are not listed as workouts
    expect((await request(app).get(`${api}/workouts`).set(auth)).body.total).toBe(0);

    await request(app).delete(`${api}/workouts/active`).set(auth).expect(204);
    expect((await request(app).get(`${api}/workouts/active`).set(auth)).body.session).toBeNull();
  });

  it('finishing converts the draft and blocks re-opening it', async () => {
    const { auth } = await lifter();
    const startedAt = new Date(Date.now() - HOUR).toISOString();
    await request(app)
      .put(`${api}/workouts/active`)
      .set(auth)
      .send({ clientId: 'draft-finish-1', startedAt, exercises: [] })
      .expect(200);
    const saved = await request(app)
      .post(`${api}/workouts`)
      .set(auth)
      .send({ clientId: 'draft-finish-1', startedAt, exercises: [bench([set(100, 5)])] });
    expect(saved.status).toBe(201);
    expect(await WorkoutSession.countDocuments({ status: 'active' })).toBe(0);

    const reopen = await request(app)
      .put(`${api}/workouts/active`)
      .set(auth)
      .send({ clientId: 'draft-finish-1', startedAt, exercises: [] });
    expect(reopen.status).toBe(409);
  });
});

describe('listing and previous values', () => {
  it('paginates newest first and returns previous sets for ghost text', async () => {
    const { auth } = await lifter();
    for (let i = 3; i >= 1; i -= 1) {
      await request(app).post(`${api}/workouts`).set(auth).send(workout([bench([set(90 + i, 5)])], { daysAgo: i }));
    }
    const page = await request(app).get(`${api}/workouts?limit=2`).set(auth);
    expect(page.body).toMatchObject({ total: 3, totalPages: 2 });
    expect(page.body.data[0].exercises[0].sets[0].weight).toBe(91);

    const benchId = ex['Barbell_Bench_Press_-_Medium_Grip'].id;
    const prev = await request(app).get(`${api}/workouts/previous?exerciseIds=${benchId},${ex.Barbell_Squat.id}`).set(auth);
    expect(prev.body.previous[benchId].sets).toEqual([{ weight: 91, reps: 5, rpe: null, type: 'working' }]);
    expect(prev.body.previous[ex.Barbell_Squat.id]).toBeNull();
  });

  it("does not expose other users' workouts", async () => {
    const a = await lifter();
    const b = await lifter();
    const { body } = await request(app).post(`${api}/workouts`).set(a.auth).send(workout([bench([set(100, 5)])]));
    expect((await request(app).get(`${api}/workouts/${body.session.id}`).set(b.auth)).status).toBe(404);
    expect((await request(app).delete(`${api}/workouts/${body.session.id}`).set(b.auth)).status).toBe(404);
  });
});
