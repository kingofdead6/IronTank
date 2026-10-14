import request from 'supertest';
import { createApp } from '../../src/app.js';
import { Program } from '../../src/models/Program.js';
import { seedPrograms } from '../../src/seed/seedPrograms.js';
import { registerUser } from '../helpers/auth.js';
import { clearDb, setupTestDb, teardownTestDb } from '../helpers/db.js';
import { seedSampleExercises } from '../helpers/fixtures.js';

const app = createApp();
const api = '/api/v1/programs';
let ex;

beforeAll(setupTestDb);
beforeEach(async () => {
  ex = await seedSampleExercises();
  await seedPrograms();
});
afterEach(clearDb);
afterAll(teardownTestDb);

const myProgram = () => ({
  name: 'My Split',
  days: [
    {
      name: 'Day 1',
      exercises: [
        { exerciseId: ex.Barbell_Squat.id, sets: 5, repRange: { min: 5, max: 5 }, restSeconds: 180 },
        { exerciseId: ex['Barbell_Bench_Press_-_Medium_Grip'].id },
      ],
    },
    { name: 'Day 2', exercises: [{ exerciseId: ex.Barbell_Deadlift.id, sets: 1 }] },
  ],
});

describe('templates', () => {
  it('seeds the four built-in templates idempotently', async () => {
    await seedPrograms();
    const keys = (await Program.find({ isTemplate: true })).map((p) => p.templateKey).sort();
    expect(keys).toEqual(['full-body-3x', 'ppl', 'strength-5x5', 'upper-lower']);
  });

  it('lists templates with exercise summaries inlined', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).get(`${api}?scope=templates`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.total).toBe(4);
    const fiveByFive = res.body.data.find((p) => p.templateKey === 'strength-5x5');
    expect(fiveByFive.days.map((d) => d.name)).toEqual(['Workout A', 'Workout B']);
    expect(fiveByFive.days[0].exercises[0]).toMatchObject({
      sets: 5,
      repRange: { min: 5, max: 5 },
      exercise: { name: 'Barbell Squat' },
    });
    expect(fiveByFive.days[0].exercises[0].exercise.image).toMatch(/^https:\/\/raw\.githubusercontent/);
  });

  it('templates are read-only', async () => {
    const { auth } = await registerUser(app);
    const tpl = await Program.findOne({ templateKey: 'ppl' });
    expect((await request(app).patch(`${api}/${tpl.id}`).set(auth).send({ name: 'x' })).status).toBe(403);
    expect((await request(app).delete(`${api}/${tpl.id}`).set(auth)).status).toBe(403);
  });
});

describe('custom programs', () => {
  it('creates, reads, updates and deletes', async () => {
    const { auth } = await registerUser(app);
    const created = await request(app).post(api).set(auth).send(myProgram());
    expect(created.status).toBe(201);
    const { program } = created.body;
    expect(program.days[0].exercises[1]).toMatchObject({ sets: 3, restSeconds: 90, repRange: { min: 8, max: 12 } });

    // Reorder exercises (drag-to-reorder in the builder sends the full days array)
    const reordered = { days: [{ ...myProgram().days[0], exercises: [...myProgram().days[0].exercises].reverse() }] };
    const updated = await request(app).patch(`${api}/${program.id}`).set(auth).send(reordered);
    expect(updated.body.program.days).toHaveLength(1);
    expect(updated.body.program.days[0].exercises[0].exercise.name).toBe('Barbell Bench Press - Medium Grip');

    expect((await request(app).delete(`${api}/${program.id}`).set(auth)).status).toBe(204);
    expect((await request(app).get(`${api}/${program.id}`).set(auth)).status).toBe(404);
  });

  it("hides other users' programs", async () => {
    const owner = await registerUser(app);
    const other = await registerUser(app);
    const { body } = await request(app).post(api).set(owner.auth).send(myProgram());
    expect((await request(app).get(`${api}/${body.program.id}`).set(other.auth)).status).toBe(404);
    const list = await request(app).get(`${api}?scope=mine`).set(other.auth);
    expect(list.body.total).toBe(0);
  });

  it('validates rep ranges and exercise ids', async () => {
    const { auth } = await registerUser(app);
    const bad = myProgram();
    bad.days[0].exercises[0].repRange = { min: 10, max: 5 };
    expect((await request(app).post(api).set(auth).send(bad)).status).toBe(422);
    const unknown = myProgram();
    unknown.days[0].exercises[0].exerciseId = '0123456789abcdef01234567';
    const res = await request(app).post(api).set(auth).send(unknown);
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('UNKNOWN_EXERCISE');
  });
});

describe('activation', () => {
  it('activating a template clones it and keeps one active program', async () => {
    const { auth } = await registerUser(app);
    const tpl = await Program.findOne({ templateKey: 'strength-5x5' });
    const res = await request(app).post(`${api}/${tpl.id}/activate`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.program).toMatchObject({ isActive: true, isTemplate: false, sourceTemplateId: tpl.id });
    expect(res.body.program.id).not.toBe(tpl.id);

    const { body: mine } = await request(app).post(api).set(auth).send(myProgram());
    await request(app).post(`${api}/${mine.program.id}/activate`).set(auth).expect(200);
    const active = await Program.find({ isActive: true });
    expect(active.map((p) => p.id)).toEqual([mine.program.id]);
  });

  it('rotates the next day after each completed session', async () => {
    const { auth } = await registerUser(app);
    const tpl = await Program.findOne({ templateKey: 'strength-5x5' });
    const { body } = await request(app).post(`${api}/${tpl.id}/activate`).set(auth);
    const [dayA, dayB] = body.program.days;

    let active = await request(app).get(`${api}/active`).set(auth);
    expect(active.body.nextDay).toMatchObject({ index: 0, name: 'Workout A' });

    await request(app)
      .post('/api/v1/workouts')
      .set(auth)
      .send({
        clientId: 'rotate-0001',
        programId: body.program.id,
        dayId: dayA.id,
        startedAt: new Date(Date.now() - 3600e3).toISOString(),
        exercises: [],
      })
      .expect(201);

    active = await request(app).get(`${api}/active`).set(auth);
    expect(active.body.nextDay).toMatchObject({ index: 1, id: dayB.id });
  });

  it('returns nulls when no program is active', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).get(`${api}/active`).set(auth);
    expect(res.body).toEqual({ program: null, nextDay: null, lastSession: null });
  });

  it('clones a template without activating it', async () => {
    const { auth } = await registerUser(app);
    const tpl = await Program.findOne({ templateKey: 'ppl' });
    const res = await request(app).post(`${api}/${tpl.id}/clone`).set(auth);
    expect(res.status).toBe(201);
    expect(res.body.program).toMatchObject({ name: 'Push / Pull / Legs', isActive: false, isTemplate: false });
    expect(res.body.program.days[0].id).not.toBe(tpl.days[0].id);
  });
});
