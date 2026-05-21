import { Router } from 'express';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { clinicalReferenceController } from './clinical-reference.controller.js';

export const clinicalReferenceRouter = Router();

clinicalReferenceRouter.use(requireAuth, requireRoles('NURSE', 'PATIENT', 'ADMIN'));

clinicalReferenceRouter.get('/', asyncHandler((req, res) => clinicalReferenceController.list(req, res)));
