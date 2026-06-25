import type { ErrorRequestHandler } from 'express';
import { Prisma } from '@prisma/client';
import { HttpError } from './http-error.js';

export const errorMiddleware: ErrorRequestHandler = (error, _req, res, _next) => {
  if (error instanceof HttpError) {
    return res.status(error.statusCode).json({
      error: {
        code: error.code,
        message: error.message,
        details: error.details
      }
    });
  }

  // Violation de contrainte d'unicité Prisma → 409 propre au lieu d'un 500 brut
  // (ex. ré-inscription d'un email soft-deleted, re-création d'un clientLocalId).
  if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
    return res.status(409).json({
      error: {
        code: 'CONFLICT',
        message: 'Cette ressource existe déjà (contrainte d’unicité).'
      }
    });
  }

  console.error(error);
  return res.status(500).json({
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Erreur interne du serveur'
    }
  });
};
