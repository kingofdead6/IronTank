/**
 * Runs a paginated Mongoose query and returns the standard list envelope:
 * `{ data, page, limit, total, totalPages }`.
 *
 * @param {import('mongoose').Model} model
 * @param {object} filter
 * @param {{ page: number, limit: number, sort?: object, select?: string|object, populate?: any, lean?: boolean, map?: (doc:any)=>any }} opts
 */
export async function paginate(model, filter, { page, limit, sort = { _id: -1 }, select, populate, map }) {
  let query = model
    .find(filter)
    .sort(sort)
    .skip((page - 1) * limit)
    .limit(limit);
  if (select) query = query.select(select);
  if (populate) query = query.populate(populate);

  const [docs, total] = await Promise.all([query, model.countDocuments(filter)]);
  return {
    data: map ? docs.map(map) : docs,
    page,
    limit,
    total,
    totalPages: Math.max(1, Math.ceil(total / limit)),
  };
}

/** Pages an in-memory array using the same envelope as `paginate`. */
export function paginateArray(items, { page, limit }) {
  const start = (page - 1) * limit;
  return {
    data: items.slice(start, start + limit),
    page,
    limit,
    total: items.length,
    totalPages: Math.max(1, Math.ceil(items.length / limit)),
  };
}
