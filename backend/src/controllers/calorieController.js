import * as service from '../services/calorieLogService.js';
import { localDay } from '../utils/dates.js';

/** One day (default today in `tz`), or a paginated range when from/to are given. */
export async function get(req, res) {
  const { date, from, to, tz, page, limit } = req.valid.query;
  if (from || to) return res.json(await service.listDays(req.userId, { from, to, page, limit }));
  res.json(await service.getDay(req.userId, date ?? localDay(new Date(), tz), tz));
}

export async function addEntry(req, res) {
  res.status(201).json(await service.addEntry(req.userId, req.valid.body));
}

export async function deleteEntry(req, res) {
  await service.deleteEntry(req.userId, req.valid.params.entryId);
  res.status(204).end();
}

export async function getTarget(req, res) {
  res.json(await service.getTarget(req.userId));
}

export async function setTarget(req, res) {
  res.json(await service.setTarget(req.userId, req.valid.body));
}
