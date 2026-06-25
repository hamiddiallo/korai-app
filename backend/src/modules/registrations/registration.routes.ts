import { Router } from 'express';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { registrationController } from './registration.controller.js';

export const registrationRouter = Router();

registrationRouter.use(requireAuth, requireRoles('SPECIALIST', 'ADMIN'));

registrationRouter.get(
  '/nurses',
  asyncHandler((req, res) => registrationController.list(req, res))
);

registrationRouter.post(
  '/nurses/:id/approve',
  asyncHandler((req, res) => registrationController.approve(req, res))
);

registrationRouter.post(
  '/nurses/:id/reject',
  asyncHandler((req, res) => registrationController.reject(req, res))
);
