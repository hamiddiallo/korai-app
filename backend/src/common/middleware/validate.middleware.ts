import type { RequestHandler } from 'express';
import type { ZodSchema } from 'zod';
import { HttpError } from '../errors/http-error.js';

export const validateBody =
  (schema: ZodSchema): RequestHandler =>
  (req, _res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      return next(new HttpError(400, 'VALIDATION_ERROR', 'Donnees invalides', result.error.flatten()));
    }
    req.body = result.data;
    return next();
  };
