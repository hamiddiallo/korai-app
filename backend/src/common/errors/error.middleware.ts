import type { ErrorRequestHandler } from 'express';
import { Prisma } from '@prisma/client';
import { HttpError } from './http-error.js';
import { audit } from '../../modules/audit/audit.service.js';

export const errorMiddleware: ErrorRequestHandler = (error, req, res, _next) => {
  if (error instanceof HttpError) {
    // Tentative d'accès à un dossier hors de son périmètre : tracée.
    if (req.user && error.statusCode === 403 && (error.code === 'OUT_OF_SCOPE' || error.code === 'FORBIDDEN')) {
      const path = req.originalUrl.split('?')[0] ?? '';
      void audit.fromRequest(req, {
        action: 'ACCESS_DENIED',
        entityType: 'AUTH',
        entityId: path.match(/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i)?.[0],
        details: { method: req.method, path, code: error.code }
      });
    }
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
