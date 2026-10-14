import { AppError } from '../utils/AppError.js';

/**
 * Validates and coerces `req.body`, `req.query` and `req.params` with zod schemas.
 * Parsed values are exposed on `req.valid.{body,query,params}` (Express 5 makes
 * `req.query` read-only, so we never overwrite it).
 *
 * @param {{ body?: import('zod').ZodTypeAny, query?: import('zod').ZodTypeAny, params?: import('zod').ZodTypeAny }} schemas
 */
export function validate(schemas) {
  return (req, _res, next) => {
    req.valid = req.valid || {};
    const issues = [];
    for (const part of ['params', 'query', 'body']) {
      const schema = schemas[part];
      if (!schema) continue;
      const result = schema.safeParse(req[part] ?? {});
      if (result.success) {
        req.valid[part] = result.data;
      } else {
        for (const issue of result.error.issues) {
          issues.push({ path: [part, ...issue.path].join('.'), message: issue.message });
        }
      }
    }
    if (issues.length) return next(AppError.validation(issues));
    next();
  };
}
