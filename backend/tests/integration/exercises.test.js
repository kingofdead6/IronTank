import request from 'supertest';
import { createApp } from '../../src/app.js';
import { Exercise } from '../../src/models/Exercise.js';
import { seedExercises } from '../../src/seed/seedExercises.js';
import { registerUser } from '../helpers/auth.js';
import { clearDb, setupTestDb, teardownTestDb } from '../helpers/db.js';
import { sampleSource, seedSampleExercises } from '../helpers/fixtures.js';

const app = createApp();
const api = '/api/v1/exercises';

beforeAll(setupTestDb);
beforeEach(seedSampleExercises);
afterEach(clearDb);
afterAll(teardownTestDb);

describe('seedExercises', () => {
  it('is idempotent', async () => {
    const again = await seedExercises({ source: sampleSource });
    expect(again.inserted).toBe(0);
    expect(await Exercise.countDocuments()).toBe(sampleSource.length);
  });
});

describe('GET /exercises', () => {
  it('lists the library paginated and sorted by name', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).get(`${api}?limit=5`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ page: 1, limit: 5, total: sampleSource.length });
    expect(res.body.data).toHaveLength(5);
    const names = res.body.data.map((e) => e.name);
    expect(names).toEqual([...names].sort((a, b) => a.localeCompare(b)));
  });

  it('searches by name (case-insensitive, regex-safe)', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).get(`${api}?q=BENCH`).set(auth);
    expect(res.body.data.map((e) => e.sourceId)).toEqual(['Barbell_Bench_Press_-_Medium_Grip']);
    const weird = await request(app).get(`${api}?q=${encodeURIComponent('(.*')}`).set(auth);
    expect(weird.status).toBe(200);
    expect(weird.body.total).toBe(0);
  });

  it('filters by muscle, equipment and category', async () => {
    const { auth } = await registerUser(app);
    const chest = await request(app).get(`${api}?muscle=chest&equipment=barbell`).set(auth);
    expect(chest.body.data.every((e) => e.equipment === 'barbell')).toBe(true);
    expect(chest.body.data.some((e) => e.sourceId === 'Barbell_Bench_Press_-_Medium_Grip')).toBe(true);

    const multi = await request(app).get(`${api}?category=stretching,cardio`).set(auth);
    expect(new Set(multi.body.data.map((e) => e.category))).toEqual(new Set(['stretching', 'cardio']));
  });

  it('rejects unknown filter values', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).get(`${api}?muscle=wings`).set(auth);
    expect(res.status).toBe(422);
  });
});

describe('GET /exercises/:id and /filters', () => {
  it('returns one exercise', async () => {
    const { auth } = await registerUser(app);
    const ex = await Exercise.findOne({ sourceId: 'Barbell_Squat' });
    const res = await request(app).get(`${api}/${ex.id}`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.exercise).toMatchObject({ name: ex.name, liftKey: 'squat' });
  });

  it('404s for unknown ids and 422s for malformed ids', async () => {
    const { auth } = await registerUser(app);
    expect((await request(app).get(`${api}/0123456789abcdef01234567`).set(auth)).status).toBe(404);
    expect((await request(app).get(`${api}/nope`).set(auth)).status).toBe(422);
  });

  it('lists filter options', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).get(`${api}/filters`).set(auth);
    expect(res.body.categories).toEqual(['strength', 'cardio', 'stretching']);
    expect(res.body.muscles).toContain('quadriceps');
  });
});

describe('custom exercises', () => {
  const body = { name: 'Landmine Press', primaryMuscles: ['shoulders'], equipment: 'barbell' };

  it('creates a custom exercise visible only to its creator', async () => {
    const owner = await registerUser(app);
    const other = await registerUser(app);

    const created = await request(app).post(api).set(owner.auth).send(body);
    expect(created.status).toBe(201);
    expect(created.body.exercise).toMatchObject({ isCustom: true, slug: 'landmine-press', metValue: 6 });

    const id = created.body.exercise.id;
    expect((await request(app).get(`${api}/${id}`).set(other.auth)).status).toBe(404);
    const mine = await request(app).get(`${api}?scope=custom`).set(owner.auth);
    expect(mine.body.data.map((e) => e.id)).toEqual([id]);
    const theirs = await request(app).get(`${api}?q=landmine`).set(other.auth);
    expect(theirs.body.total).toBe(0);
  });

  it('dedupes slugs per user', async () => {
    const { auth } = await registerUser(app);
    await request(app).post(api).set(auth).send(body);
    const second = await request(app).post(api).set(auth).send(body);
    expect(second.body.exercise.slug).toBe('landmine-press-2');
  });

  it('updates and deletes own customs but not library exercises', async () => {
    const { auth } = await registerUser(app);
    const { body: c } = await request(app).post(api).set(auth).send(body);

    const patched = await request(app).patch(`${api}/${c.exercise.id}`).set(auth).send({ equipment: 'machine' });
    expect(patched.body.exercise).toMatchObject({ equipment: 'machine', metValue: 4 });

    const lib = await Exercise.findOne({ createdBy: null });
    expect((await request(app).patch(`${api}/${lib.id}`).set(auth).send({ name: 'Hacked' })).status).toBe(403);
    expect((await request(app).delete(`${api}/${lib.id}`).set(auth)).status).toBe(403);

    expect((await request(app).delete(`${api}/${c.exercise.id}`).set(auth)).status).toBe(204);
  });

  it('validates the payload', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).post(api).set(auth).send({ name: 'x', primaryMuscles: [] });
    expect(res.status).toBe(422);
  });
});
