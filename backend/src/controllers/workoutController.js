import * as service from '../services/workoutService.js';

export async function create(req, res) {
  const { duplicate, ...result } = await service.saveCompletedSession(req.userId, req.valid.body);
  res.status(duplicate ? 200 : 201).json(result);
}

export async function list(req, res) {
  res.json(await service.listSessions(req.userId, req.valid.query));
}

export async function getOne(req, res) {
  res.json({ session: await service.getSession(req.userId, req.valid.params.id) });
}

export async function update(req, res) {
  res.json(await service.updateSession(req.userId, req.valid.params.id, req.valid.body));
}

export async function remove(req, res) {
  await service.deleteSession(req.userId, req.valid.params.id);
  res.status(204).end();
}

export async function getActive(req, res) {
  res.json({ session: await service.getActive(req.userId) });
}

export async function putActive(req, res) {
  res.json({ session: await service.putActive(req.userId, req.valid.body) });
}

export async function deleteActive(req, res) {
  await service.deleteActive(req.userId);
  res.status(204).end();
}

export async function previous(req, res) {
  res.json({ previous: await service.previousSets(req.userId, req.valid.query.exerciseIds) });
}
