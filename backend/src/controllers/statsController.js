import { exerciseHistory, overview } from '../services/statsService.js';

export async function getOverview(req, res) {
  res.json(await overview(req.userId, req.valid.query));
}

export async function getExercise(req, res) {
  res.json(await exerciseHistory(req.userId, req.valid.params.exerciseId, req.valid.query));
}
