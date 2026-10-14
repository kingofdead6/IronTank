import request from 'supertest';
import { createApp } from '../../src/app.js';
import { localDay } from '../../src/utils/dates.js';
import { registerUser } from '../helpers/auth.js';
import { clearDb, setupTestDb, teardownTestDb } from '../helpers/db.js';
import { seedSampleExercises } from '../helpers/fixtures.js';

const app = createApp();
const api = '/api/v1';
const HOUR = 3600e3;
let ex;
let seq = 0;

beforeAll(setupTestDb);
beforeEach(async () => {
  ex = await seedSampleExercises();
});
afterEach(clearDb);
afterAll(teardownTestDb);

const set = (weight, reps) => ({ weight, reps, completed: true, type: 'working' });

async function saveWorkout(auth, daysAgo, exercises) {
  seq += 1;
  const startedAt = new Date(Date.now() - daysAgo * 24 * HOUR - 2 * HOUR);
  return request(app)
    .post(`${api}/workouts`)
    .set(auth)
    .send({
      clientId: `stats-${seq}-${Date.now()}`,
      startedAt: startedAt.toISOString(),
      endedAt: new Date(startedAt.getTime() + HOUR).toISOString(),
      exercises,
    })
    .expect(201);
}

async function lifter() {
  const u = await registerUser(app);
  await request(app)
    .patch(`${api}/users/me`)
    .set(u.auth)
    .send({ sex: 'male', bodyweightKg: 80, heightCm: 180, birthDate: '1995-01-01', activityLevel: 'moderate' })
    .expect(200);
  return u;
}

describe('GET /stats/overview', () => {
  it('summarises weekly volume, streaks, muscle distribution and heatmap', async () => {
    const { auth } = await lifter();
    const benchEx = { exerciseId: ex['Barbell_Bench_Press_-_Medium_Grip'].id, sets: [set(100, 5), set(100, 5)] };
    const squatEx = { exerciseId: ex.Barbell_Squat.id, sets: [set(120, 5)] };
    await saveWorkout(auth, 0, [benchEx]);
    await saveWorkout(auth, 1, [squatEx]);
    await saveWorkout(auth, 15, [benchEx]);

    const res = await request(app).get(`${api}/stats/overview?weeks=4`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.weekly).toHaveLength(4);
    expect(res.body.totals).toMatchObject({ sessions: 3, volume: 2600 });
    expect(res.body.streak.days).toBe(2);
    expect(res.body.streak.weeks).toBeGreaterThanOrEqual(1);
    const dist = Object.fromEntries(res.body.muscleDistribution.map((d) => [d.group, d.sets]));
    expect(dist.chest).toBe(4);
    expect(dist.legs).toBeGreaterThan(0);
    expect(res.body.heatmap.map((d) => d.date)).toContain(localDay(new Date(Date.now() - 2 * HOUR)));
    expect(res.body.daysSinceLastWorkout).toBe(0);
  });

  it('validates the time zone', async () => {
    const { auth } = await lifter();
    expect((await request(app).get(`${api}/stats/overview?tz=Mars/Base`).set(auth)).status).toBe(422);
    expect((await request(app).get(`${api}/stats/overview?tz=Africa/Algiers`).set(auth)).status).toBe(200);
  });
});

describe('GET /stats/exercise/:id', () => {
  it('returns per-session e1RM history, newest first', async () => {
    const { auth } = await lifter();
    const id = ex['Barbell_Bench_Press_-_Medium_Grip'].id;
    await saveWorkout(auth, 3, [{ exerciseId: id, sets: [set(100, 5)] }]);
    await saveWorkout(auth, 1, [{ exerciseId: id, sets: [set(100, 8), set(80, 10)] }]);

    const res = await request(app).get(`${api}/stats/exercise/${id}`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.data.map((d) => d.bestE1rm)).toEqual([126.7, 116.7]);
    expect(res.body.data[0]).toMatchObject({ topSet: { weight: 100, reps: 8 }, sets: 2, volume: 1600 });
    expect(res.body.bests.e1rm.value).toBe(126.7);
    expect(res.body.total).toBe(2);
  });
});

describe('/calories', () => {
  it('computes a TDEE target from the profile', async () => {
    const { auth } = await lifter();
    const res = await request(app).get(`${api}/calories/target`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.profileIncomplete).toBe(false);
    expect(res.body.tdee.targets).toHaveProperty('cut');
    expect(res.body.effectiveTargetKcal).toBe(res.body.tdee.targets.maintain.kcal);
  });

  it('reports which profile fields are missing', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).get(`${api}/calories/target`).set(auth);
    expect(res.body).toMatchObject({ profileIncomplete: true, effectiveTargetKcal: null });
    expect(res.body.missing).toEqual(expect.arrayContaining(['sex', 'birthDate', 'heightCm', 'bodyweightKg']));
  });

  it('logs entries and shows consumed vs target with burned calories', async () => {
    const { auth } = await lifter();
    await saveWorkout(auth, 0, [{ exerciseId: ex.Barbell_Squat.id, sets: [set(100, 5)] }]);
    const today = localDay(new Date(Date.now() - 2 * HOUR));

    const add = await request(app)
      .post(`${api}/calories/entries`)
      .set(auth)
      .send({ date: today, name: 'Oats', kcal: 400, protein: 15, carbs: 60, fat: 8 });
    expect(add.status).toBe(201);
    await request(app).post(`${api}/calories/entries`).set(auth).send({ date: today, name: 'Shake', kcal: 250, protein: 40 });

    const day = await request(app).get(`${api}/calories?date=${today}`).set(auth);
    expect(day.body.consumed).toEqual({ kcal: 650, protein: 55, carbs: 60, fat: 8 });
    expect(day.body.entries).toHaveLength(2);
    expect(day.body.burned.kcal).toBe(480); // MET 6 × 80 kg × 1 h
    expect(day.body.remainingKcal).toBe(day.body.targetKcal - 650 + 480);

    await request(app).delete(`${api}/calories/entries/${day.body.entries[0].id}`).set(auth).expect(204);
    const after = await request(app).get(`${api}/calories?date=${today}`).set(auth);
    expect(after.body.consumed.kcal).toBe(250);
  });

  it('supports a manual target override and lists days paginated', async () => {
    const { auth } = await lifter();
    await request(app).post(`${api}/calories/entries`).set(auth).send({ date: '2026-01-01', name: 'A', kcal: 100 });
    await request(app).post(`${api}/calories/entries`).set(auth).send({ date: '2026-01-02', name: 'B', kcal: 200 });

    const set1 = await request(app).put(`${api}/calories/target`).set(auth).send({ targetKcal: 2222, date: '2026-01-02' });
    expect(set1.body).toMatchObject({ customTargetKcal: 2222, effectiveTargetKcal: 2222 });

    const list = await request(app).get(`${api}/calories?from=2026-01-01&to=2026-01-31&limit=1`).set(auth);
    expect(list.body).toMatchObject({ total: 2, totalPages: 2 });
    expect(list.body.data[0]).toMatchObject({ date: '2026-01-02', targetKcal: 2222, consumed: { kcal: 200 } });

    const cleared = await request(app).put(`${api}/calories/target`).set(auth).send({ targetKcal: null, goal: 'bulk' });
    expect(cleared.body.effectiveTargetKcal).toBe(cleared.body.tdee.targets.bulk.kcal);
  });
});
