import mongoose from 'mongoose';
import { AppError } from '../utils/AppError.js';
import { env } from '../config/env.js';

/** 404 for any route that did not match. */
export function notFound(req, _res, next) {
  next(new AppError(404, 'ROUTE_NOT_FOUND', `Route ${req.method} ${req.originalUrl} not found`));
}

/**
 * Central error handler. Every error leaves the API as
 * `{ error: { code, message, details? } }` with an appropriate status.
 */
// eslint-disable-next-line no-unused-vars
export function errorHandler(err, _req, res, _next) {
  let error = err;

  if (!(error instanceof AppError)) {
    if (error instanceof mongoose.Error.CastError) {
      error = AppError.badRequest(`Invalid ${error.path}: ${error.value}`);
    } else if (error instanceof mongoose.Error.ValidationError) {
      const details = Object.values(error.errors).map((e) => ({ path: e.path, message: e.message }));
      error = AppError.validation(details);
    } else if (error?.code === 11000) {
      const field = Object.keys(error.keyValue || {})[0] || 'field';
      error = AppError.conflict(`A record with this ${field} already exists`, 'DUPLICATE_KEY');
    } else if (error?.type === 'entity.parse.failed') {
      error = AppError.badRequest('Malformed JSON body');
    } else if (error?.type === 'entity.too.large') {
      error = new AppError(413, 'PAYLOAD_TOO_LARGE', 'Request body is too large');
    } else {
      if (!env.isTest || process.env.DEBUG_ERRORS) console.error(error);
      error = new AppError(500, 'INTERNAL_ERROR', 'Something went wrong');
    }
  }

  const body = { error: { code: error.code, message: error.message } };
  if (error.details) body.error.details = error.details;
  res.status(error.status).json(body);
}
