import request from 'supertest';
import { createApp } from '../../src/app.js';
import { RefreshToken } from '../../src/models/RefreshToken.js';
import { hashToken } from '../../src/services/tokenService.js';
import { registerUser } from '../helpers/auth.js';
import { clearDb, setupTestDb, teardownTestDb } from '../helpers/db.js';

const app = createApp();
const api = '/api/v1';

beforeAll(setupTestDb);
afterEach(clearDb);
afterAll(teardownTestDb);

describe('POST /auth/register', () => {
  it('creates a user and returns a token pair without leaking the hash', async () => {
    const res = await request(app)
      .post(`${api}/auth/register`)
      .send({ email: 'New@Lifter.dev', password: 'Sup3rSecret!', username: 'newbie' });

    expect(res.status).toBe(201);
    expect(res.body.user).toMatchObject({ email: 'new@lifter.dev', username: 'newbie', unit: 'kg' });
    expect(res.body.user.passwordHash).toBeUndefined();
    expect(res.body.tokens.accessToken).toEqual(expect.any(String));
    expect(res.body.tokens.refreshToken).toEqual(expect.any(String));
  });

  it('stores only a hash of the refresh token', async () => {
    const { refreshToken } = await registerUser(app);
    const stored = await RefreshToken.findOne({});
    expect(stored.tokenHash).toBe(hashToken(refreshToken));
    expect(stored.tokenHash).not.toBe(refreshToken);
  });

  it('rejects duplicate emails with 409', async () => {
    await registerUser(app, { email: 'dup@test.dev' });
    const res = await request(app)
      .post(`${api}/auth/register`)
      .send({ email: 'dup@test.dev', password: 'Sup3rSecret!', username: 'again' });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('EMAIL_TAKEN');
  });

  it('validates input with a consistent error shape', async () => {
    const res = await request(app)
      .post(`${api}/auth/register`)
      .send({ email: 'not-an-email', password: 'short', username: 'x' });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    const paths = res.body.error.details.map((d) => d.path);
    expect(paths).toEqual(expect.arrayContaining(['body.email', 'body.password', 'body.username']));
  });
});

describe('POST /auth/login', () => {
  it('logs in with valid credentials', async () => {
    const { user, password } = await registerUser(app);
    const res = await request(app).post(`${api}/auth/login`).send({ email: user.email, password });
    expect(res.status).toBe(200);
    expect(res.body.user.id).toBe(user.id);
    expect(res.body.tokens.accessToken).toBeTruthy();
  });

  it('returns the same error for wrong password and unknown email', async () => {
    const { user } = await registerUser(app);
    const wrong = await request(app).post(`${api}/auth/login`).send({ email: user.email, password: 'nope-nope' });
    const unknown = await request(app)
      .post(`${api}/auth/login`)
      .send({ email: 'ghost@test.dev', password: 'whatever1' });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.body.error).toEqual(unknown.body.error);
  });
});

describe('POST /auth/refresh (rotation)', () => {
  it('rotates the refresh token and revokes the old one', async () => {
    const { refreshToken } = await registerUser(app);
    const res = await request(app).post(`${api}/auth/refresh`).send({ refreshToken });
    expect(res.status).toBe(200);
    expect(res.body.tokens.refreshToken).not.toBe(refreshToken);

    const old = await RefreshToken.findOne({ tokenHash: hashToken(refreshToken) });
    expect(old.revokedAt).not.toBeNull();
    expect(old.replacedByHash).toBe(hashToken(res.body.tokens.refreshToken));
  });

  it('detects reuse of a rotated token and revokes the whole family', async () => {
    const { refreshToken } = await registerUser(app);
    const first = await request(app).post(`${api}/auth/refresh`).send({ refreshToken });
    const newToken = first.body.tokens.refreshToken;

    const reuse = await request(app).post(`${api}/auth/refresh`).send({ refreshToken });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.code).toBe('REFRESH_TOKEN_REUSED');

    // The legitimately rotated token is now revoked as well.
    const after = await request(app).post(`${api}/auth/refresh`).send({ refreshToken: newToken });
    expect(after.status).toBe(401);
  });

  it('rejects garbage tokens', async () => {
    const res = await request(app).post(`${api}/auth/refresh`).send({ refreshToken: 'definitely-not-a-jwt' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_REFRESH_TOKEN');
  });

  it('rejects an access token presented as a refresh token', async () => {
    const { accessToken } = await registerUser(app);
    const res = await request(app).post(`${api}/auth/refresh`).send({ refreshToken: accessToken });
    expect(res.status).toBe(401);
  });
});

describe('POST /auth/logout', () => {
  it('revokes the presented refresh token', async () => {
    const { refreshToken } = await registerUser(app);
    const res = await request(app).post(`${api}/auth/logout`).send({ refreshToken });
    expect(res.status).toBe(204);
    const again = await request(app).post(`${api}/auth/refresh`).send({ refreshToken });
    expect(again.status).toBe(401);
  });

  it('revokes all sessions when allDevices is set', async () => {
    const { user, password, auth } = await registerUser(app);
    const second = await request(app).post(`${api}/auth/login`).send({ email: user.email, password });
    const res = await request(app).post(`${api}/auth/logout`).set(auth).send({ allDevices: true });
    expect(res.status).toBe(204);
    expect(await RefreshToken.countDocuments({ userId: user.id, revokedAt: null })).toBe(0);
    const refresh = await request(app)
      .post(`${api}/auth/refresh`)
      .send({ refreshToken: second.body.tokens.refreshToken });
    expect(refresh.status).toBe(401);
  });
});

describe('POST /auth/forgot-password', () => {
  it('responds identically whether or not the account exists', async () => {
    const { user } = await registerUser(app);
    const known = await request(app).post(`${api}/auth/forgot-password`).send({ email: user.email });
    const unknown = await request(app).post(`${api}/auth/forgot-password`).send({ email: 'nobody@test.dev' });
    expect(known.status).toBe(202);
    expect(unknown.status).toBe(202);
    expect(known.body).toEqual(unknown.body);
  });
});

describe('protected routes', () => {
  it('requires a bearer token', async () => {
    const res = await request(app).get(`${api}/users/me`);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('rejects a tampered token', async () => {
    const { accessToken } = await registerUser(app);
    const res = await request(app)
      .get(`${api}/users/me`)
      .set('Authorization', `Bearer ${accessToken.slice(0, -2)}xx`);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_TOKEN');
  });
});
