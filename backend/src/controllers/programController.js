import * as service from '../services/programService.js';

export async function list(req, res) {
  res.json(await service.listPrograms(req.userId, req.valid.query));
}

export async function active(req, res) {
  res.json(await service.activeProgramWithNextDay(req.userId));
}

export async function deactivate(req, res) {
  await service.deactivateProgram(req.userId);
  res.status(204).end();
}

export async function getOne(req, res) {
  res.json({ program: await service.getProgram(req.userId, req.valid.params.id) });
}

export async function create(req, res) {
  res.status(201).json({ program: await service.createProgram(req.userId, req.valid.body) });
}

export async function update(req, res) {
  res.json({ program: await service.updateProgram(req.userId, req.valid.params.id, req.valid.body) });
}

export async function remove(req, res) {
  await service.deleteProgram(req.userId, req.valid.params.id);
  res.status(204).end();
}

export async function clone(req, res) {
  res.status(201).json({ program: await service.cloneProgram(req.userId, req.valid.params.id) });
}

export async function activate(req, res) {
  res.json({ program: await service.activateProgram(req.userId, req.valid.params.id) });
}
