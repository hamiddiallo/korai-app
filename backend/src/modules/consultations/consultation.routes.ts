import { Router } from 'express';
import multer from 'multer';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { HttpError } from '../../common/errors/http-error.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import { createConsultationSchema, specialistReviewSchema } from './consultation.schemas.js';
import { consultationController } from './consultation.controller.js';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 8 * 1024 * 1024,
    files: 1
  },
  fileFilter: (_req, file, callback) => {
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.mimetype)) {
      return callback(new HttpError(400, 'INVALID_IMAGE_TYPE', 'Image JPEG, PNG ou WebP requise'));
    }
    return callback(null, true);
  }
});

export const consultationRouter = Router();

consultationRouter.use(requireAuth);

consultationRouter.get(
  '/',
  requireRoles('NURSE', 'SPECIALIST', 'ADMIN', 'PATIENT'),
  asyncHandler((req, res) => consultationController.list(req, res))
);

consultationRouter.post(
  '/diagnose',
  requireRoles('NURSE', 'ADMIN', 'PATIENT'),
  upload.single('file'),
  validateBody(createConsultationSchema),
  asyncHandler((req, res) => consultationController.diagnose(req, res))
);

consultationRouter.post(
  '/:id/request-specialist-review',
  requireRoles('NURSE', 'ADMIN'),
  asyncHandler((req, res) => consultationController.requestSpecialistReview(req, res))
);

consultationRouter.post(
  '/:id/specialist-review',
  requireRoles('SPECIALIST', 'ADMIN'),
  validateBody(specialistReviewSchema),
  asyncHandler((req, res) => consultationController.completeSpecialistReview(req, res))
);
