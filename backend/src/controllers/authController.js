import * as authService from '../services/authService.js';

const sessionResponse = ({ user, accessToken, refreshToken }) => ({
  user,
  tokens: { accessToken, refreshToken, tokenType: 'Bearer' },
});

export async function register(req, res) {
  const result = await authService.register(req.valid.body);
  res.status(201).json(sessionResponse(result));
}

export async function login(req, res) {
  const result = await authService.login(req.valid.body);
  res.json(sessionResponse(result));
}

export async function refresh(req, res) {
  const result = await authService.refresh(req.valid.body.refreshToken);
  res.json(sessionResponse(result));
}

export async function logout(req, res) {
  await authService.logout({
    refreshToken: req.valid.body.refreshToken,
    allDevices: req.valid.body.allDevices,
    userId: req.userId,
  });
  res.status(204).end();
}

export async function forgotPassword(req, res) {
  const result = await authService.forgotPassword(req.valid.body);
  res.status(202).json(result);
}
