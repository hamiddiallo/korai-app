import { Router } from 'express';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import {
  adminRegisterSchema,
  loginSchema,
  registerNurseSchema,
  registerPatientSchema,
  updateProfileSchema,
  updatePasswordSchema
} from './auth.schemas.js';
import { authController } from './auth.controller.js';

export const authRouter = Router();

authRouter.post('/login', validateBody(loginSchema), asyncHandler((req, res) => authController.login(req, res)));

authRouter.post(
  '/register/patient',
  validateBody(registerPatientSchema),
  asyncHandler((req, res) => authController.registerPatient(req, res))
);

authRouter.post(
  '/register/nurse',
  validateBody(registerNurseSchema),
  asyncHandler((req, res) => authController.registerNurse(req, res))
);

authRouter.post(
  '/register',
  requireAuth,
  requireRoles('ADMIN'),
  validateBody(adminRegisterSchema),
  asyncHandler((req, res) => authController.register(req, res))
);

authRouter.get('/me', requireAuth, (req, res) => authController.me(req, res));

authRouter.patch(
  '/me',
  requireAuth,
  validateBody(updateProfileSchema),
  asyncHandler((req, res) => authController.updateProfile(req, res))
);

authRouter.patch(
  '/me/password',
  requireAuth,
  validateBody(updatePasswordSchema),
  asyncHandler((req, res) => authController.updatePassword(req, res))
);
