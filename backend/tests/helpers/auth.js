import request from 'supertest';

let counter = 0;

/** Registers a fresh user and returns `{ user, accessToken, refreshToken, auth }`. */
export async function registerUser(app, overrides = {}) {
  counter += 1;
  const body = {
    email: `user${counter}_${Date.now()}@test.dev`,
    password: 'Sup3rSecret!',
    username: `lifter${counter}`,
    ...overrides,
  };
  const res = await request(app).post('/api/v1/auth/register').send(body);
  if (res.status !== 201) throw new Error(`register failed: ${res.status} ${JSON.stringify(res.body)}`);
  const { accessToken, refreshToken } = res.body.tokens;
  return {
    user: res.body.user,
    accessToken,
    refreshToken,
    password: body.password,
    auth: { Authorization: `Bearer ${accessToken}` },
  };
}
