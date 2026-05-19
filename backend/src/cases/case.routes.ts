import { Router } from 'express';
import multer from 'multer';
import { requireAuth, requireRoles } from '../auth/auth.middleware.js';
import { asyncHandler } from '../common/async-handler.js';
import { HttpError } from '../common/http-error.js';
import { createAiCaseFieldsSchema, specialistReviewSchema } from './case.schemas.js';
import { caseService } from './case.service.js';

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

export const caseRouter = Router();

caseRouter.use(requireAuth);

caseRouter.get(
  '/',
  requireRoles('NURSE', 'SPECIALIST', 'ADMIN', 'PATIENT'),
  asyncHandler(async (req, res) => {
    res.json({ cases: await caseService.listForUser(req.user!) });
  })
);

caseRouter.post(
  '/diagnose',
  requireRoles('NURSE', 'ADMIN', 'PATIENT'),
  upload.single('file'),
  asyncHandler(async (req, res) => {
    const parsed = createAiCaseFieldsSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Donnees invalides', parsed.error.flatten());
    }

    if (!req.file) {
      const orlCase = await caseService.createDraft({
        createdByUserId: req.user!.id,
        patientId: parsed.data.patientId,
        symptoms: parsed.data.symptoms,
        clinicalNotes: parsed.data.clinicalNotes,
        urgency: parsed.data.urgency
      });
      return res.status(201).json({ case: orlCase });
    }

    const orlCase = await caseService.createWithAi({
      createdByUserId: req.user!.id,
      patientId: parsed.data.patientId,
      symptoms: parsed.data.symptoms,
      clinicalNotes: parsed.data.clinicalNotes,
      urgency: parsed.data.urgency,
      image: req.file,
      showSources: parsed.data.showSources,
      requestSpecialistReview: parsed.data.requestSpecialistReview
    });

    res.status(201).json({ case: orlCase });
  })
);

caseRouter.post(
  '/:id/request-specialist-review',
  requireRoles('NURSE', 'ADMIN'),
  asyncHandler(async (req, res) => {
    res.json({ case: await caseService.requestSpecialistReview(String(req.params.id)) });
  })
);

caseRouter.post(
  '/:id/specialist-review',
  requireRoles('SPECIALIST', 'ADMIN'),
  asyncHandler(async (req, res) => {
    const parsed = specialistReviewSchema.safeParse(req.body);
    if (!parsed.success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Donnees invalides', parsed.error.flatten());
    }
    res.json({ case: await caseService.completeSpecialistReview(String(req.params.id), req.user!.id, parsed.data) });
  })
);
