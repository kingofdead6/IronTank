import * as service from '../services/exerciseService.js';

export async function list(req, res) {
  res.json(await service.listExercises(req.userId, req.valid.query));
}

export async function filters(_req, res) {
  res.json(service.filterOptions());
}

export async function getOne(req, res) {
  res.json({ exercise: await service.getExercise(req.userId, req.valid.params.id) });
}

export async function create(req, res) {
  const exercise = await service.createCustomExercise(req.userId, req.valid.body);
  res.status(201).json({ exercise });
}

export async function update(req, res) {
  const exercise = await service.updateCustomExercise(req.userId, req.valid.params.id, req.valid.body);
  res.json({ exercise });
}

export async function remove(req, res) {
  await service.deleteCustomExercise(req.userId, req.valid.params.id);
  res.status(204).end();
}
