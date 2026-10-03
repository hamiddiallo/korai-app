import type { ErrorRequestHandler } from 'express';
import { Prisma } from '@prisma/client';
import multer from 'multer';
import { HttpError } from './http-error.js';
import { audit } from '../../modules/audit/audit.service.js';

/** Envoi de photos refusé par multer : message clair au lieu d'une erreur interne. */
const uploadError = (error: multer.MulterError) => {
  if (error.code === 'LIMIT_FILE_SIZE') {
    return new HttpError(413, 'IMAGE_TOO_LARGE', 'Photo trop lourde : 8 Mo au maximum par photo.');
  }
  if (error.code === 'LIMIT_FILE_COUNT' || error.code === 'LIMIT_UNEXPECTED_FILE') {
    return new HttpError(400, 'VALIDATION_ERROR', 'Une photo par oreille au plus (fileRight, fileLeft).');
  }
  return new HttpError(400, 'VALIDATION_ERROR', 'Envoi de la photo impossible : vérifiez le fichier puis réessayez.');
};

export const errorMiddleware: ErrorRequestHandler = (rawError, req, res, _next) => {
  const error = rawError instanceof multer.MulterError ? uploadError(rawError) : rawError;
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
