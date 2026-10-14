import request from 'supertest';
import { createApp } from '../../src/app.js';
import { registerUser } from '../helpers/auth.js';
import { clearDb, setupTestDb, teardownTestDb } from '../helpers/db.js';

const app = createApp();
const api = '/api/v1';

beforeAll(setupTestDb);
afterEach(clearDb);
afterAll(teardownTestDb);

describe('/users/me', () => {
  it('returns the current user', async () => {
    const { user, auth } = await registerUser(app);
    const res = await request(app).get(`${api}/users/me`).set(auth);
    expect(res.status).toBe(200);
    expect(res.body.user.id).toBe(user.id);
  });

  it('updates the profile and records bodyweight history', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).patch(`${api}/users/me`).set(auth).send({
      sex: 'female',
      birthDate: '1995-04-12',
      heightCm: 168,
      bodyweightKg: 62.5,
      unit: 'lb',
      goal: 'bulk',
      onboardingComplete: true,
    });
    expect(res.status).toBe(200);
    expect(res.body.user).toMatchObject({ sex: 'female', heightCm: 168, bodyweightKg: 62.5, unit: 'lb' });

    const history = await request(app).get(`${api}/users/me/bodyweight`).set(auth);
    expect(history.body.total).toBe(1);
    expect(history.body.data[0].kg).toBe(62.5);
  });

  it('rejects unknown fields and protected fields', async () => {
    const { auth } = await registerUser(app);
    const res = await request(app).patch(`${api}/users/me`).set(auth).send({ email: 'hack@x.dev' });
    expect(res.status).toBe(422);
  });
});

describe('/users/me/bodyweight', () => {
  it('adds entries, keeps current bodyweight at the latest, and paginates', async () => {
    const { auth } = await registerUser(app);
    for (const [i, kg] of [80, 81, 79.5].entries()) {
      await request(app)
        .post(`${api}/users/me/bodyweight`)
        .set(auth)
        .send({ kg, date: new Date(2026, 0, i + 1).toISOString() })
        .expect(201);
    }
    const me = await request(app).get(`${api}/users/me`).set(auth);
    expect(me.body.user.bodyweightKg).toBe(79.5);

    const page = await request(app).get(`${api}/users/me/bodyweight?page=1&limit=2`).set(auth);
    expect(page.body).toMatchObject({ page: 1, limit: 2, total: 3, totalPages: 2 });
    expect(page.body.data.map((e) => e.kg)).toEqual([79.5, 81]);
  });
});

describe('error handling', () => {
  it('returns JSON 404 for unknown routes', async () => {
    const res = await request(app).get(`${api}/nope`);
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('ROUTE_NOT_FOUND');
  });

  it('returns JSON 400 for malformed bodies', async () => {
    const res = await request(app)
      .post(`${api}/auth/login`)
      .set('Content-Type', 'application/json')
      .send('{"email":');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('BAD_REQUEST');
  });
});
