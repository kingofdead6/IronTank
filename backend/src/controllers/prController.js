import { listRecords, recordsForExercise } from '../services/prService.js';

export async function list(req, res) {
  res.json(await listRecords(req.userId, req.valid.query));
}

export async function forExercise(req, res) {
  res.json(await recordsForExercise(req.userId, req.valid.params.exerciseId, req.valid.query));
}
