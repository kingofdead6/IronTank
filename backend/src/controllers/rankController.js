import { ranksForUser } from '../services/rankService.js';

export async function get(req, res) {
  const { ranks } = await ranksForUser(req.userId);
  res.json(ranks);
}
