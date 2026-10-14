/**
 * Shared Mongoose `toJSON` options: exposes `id` instead of `_id` and drops `__v`.
 * Idempotent, because a populated document referenced in several places is
 * serialised more than once.
 *
 * @param {(ret: object) => void} [extra]  additional per-model cleanup
 */
export function jsonOptions(extra) {
  return {
    versionKey: false,
    transform(_doc, ret) {
      if (ret._id !== undefined) {
        ret.id = ret._id.toString();
        delete ret._id;
      }
      extra?.(ret);
      return ret;
    },
  };
}
