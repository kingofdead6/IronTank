import { User } from '../models/User.js';
import { AppError } from '../utils/AppError.js';
import { paginateArray } from '../utils/pagination.js';

async function loadUser(userId) {
  const user = await User.findById(userId);
  if (!user) throw AppError.notFound('User');
  return user;
}

export async function getMe(req, res) {
  res.json({ user: await loadUser(req.userId) });
}

export async function updateMe(req, res) {
  const user = await loadUser(req.userId);
  const updates = req.valid.body;

  // Changing bodyweight through the profile also records a history point.
  if (updates.bodyweightKg !== undefined && updates.bodyweightKg !== user.bodyweightKg) {
    user.bodyweightHistory.push({ kg: updates.bodyweightKg, date: new Date() });
  }
  user.set(updates);
  await user.save();
  res.json({ user });
}

export async function addBodyweight(req, res) {
  const user = await loadUser(req.userId);
  const { kg, date = new Date() } = req.valid.body;
  user.bodyweightHistory.push({ kg, date });

  // The current bodyweight follows the most recent entry.
  const latest = [...user.bodyweightHistory].sort((a, b) => b.date - a.date)[0];
  user.bodyweightKg = latest.kg;
  await user.save();

  const entry = user.bodyweightHistory[user.bodyweightHistory.length - 1];
  res.status(201).json({ entry: { id: entry._id, kg: entry.kg, date: entry.date }, user });
}

export async function listBodyweight(req, res) {
  const user = await User.findById(req.userId).select('bodyweightHistory');
  if (!user) throw AppError.notFound('User');
  const { page, limit, from, to } = req.valid.query;

  const items = user.bodyweightHistory
    .filter((e) => (!from || e.date >= from) && (!to || e.date <= to))
    .sort((a, b) => b.date - a.date)
    .map((e) => ({ id: e._id, kg: e.kg, date: e.date }));

  res.json(paginateArray(items, { page, limit }));
}

export async function deleteBodyweight(req, res) {
  const user = await loadUser(req.userId);
  const entry = user.bodyweightHistory.id(req.valid.params.entryId);
  if (!entry) throw AppError.notFound('Bodyweight entry');
  entry.deleteOne();
  const latest = [...user.bodyweightHistory].sort((a, b) => b.date - a.date)[0];
  if (latest) user.bodyweightKg = latest.kg;
  await user.save();
  res.status(204).end();
}
