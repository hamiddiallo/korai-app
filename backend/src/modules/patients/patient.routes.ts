import { Router } from 'express';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import { createPatientSchema } from './patient.schemas.js';
import { patientController } from './patient.controller.js';

export const patientRouter = Router();

patientRouter.use(requireAuth);

patientRouter.get(
  '/',
  requireRoles('NURSE', 'SPECIALIST', 'ADMIN'),
  asyncHandler((req, res) => patientController.list(req, res))
);

patientRouter.post(
  '/',
  requireRoles('NURSE', 'ADMIN'),
  validateBody(createPatientSchema),
  asyncHandler((req, res) => patientController.create(req, res))
);

patientRouter.get(
  '/:id',
  requireRoles('NURSE', 'SPECIALIST', 'ADMIN', 'PATIENT'),
  asyncHandler((req, res) => patientController.getById(req, res))
);

patientRouter.patch('/:id', asyncHandler((req, res) => patientController.update(req, res)));
