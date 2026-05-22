import { Router } from 'express';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import { expertiseController } from './expertise.controller.js';
import { requestExpertiseSchema, submitExpertiseReviewSchema } from './expertise.schemas.js';

export const expertiseRouter = Router();

expertiseRouter.use(requireAuth);

expertiseRouter.get(
  '/inbox',
  requireRoles('SPECIALIST', 'ADMIN'),
  asyncHandler((req, res) => expertiseController.inbox(req, res))
);

export const caseExpertiseRouter = Router({ mergeParams: true });

caseExpertiseRouter.use(requireAuth);

caseExpertiseRouter.post(
  '/request',
  requireRoles('NURSE', 'ADMIN'),
  validateBody(requestExpertiseSchema),
  asyncHandler((req, res) => expertiseController.request(req, res))
);

caseExpertiseRouter.post(
  '/assign',
  requireRoles('SPECIALIST', 'ADMIN'),
  asyncHandler((req, res) => expertiseController.assign(req, res))
);

caseExpertiseRouter.post(
  '/review',
  requireRoles('SPECIALIST', 'ADMIN'),
  validateBody(submitExpertiseReviewSchema),
  asyncHandler((req, res) => expertiseController.submitReview(req, res))
);
