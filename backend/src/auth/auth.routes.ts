import { Router } from 'express';
import { asyncHandler } from '../common/async-handler.js';
import { validateBody } from '../common/validate.js';
import { authService } from './auth.service.js';
import { adminRegisterSchema, loginSchema, registerNurseSchema, registerPatientSchema } from './auth.schemas.js';
import { requireAuth, requireRoles } from './auth.middleware.js';

export const authRouter = Router();

authRouter.post(
  '/login',
  validateBody(loginSchema),
  asyncHandler(async (req, res) => {
    res.json(await authService.login(req.body));
  })
);

authRouter.post(
  '/register/patient',
  validateBody(registerPatientSchema),
  asyncHandler(async (req, res) => {
    res.status(201).json(await authService.registerPatient(req.body));
  })
);

authRouter.post(
  '/register/nurse',
  validateBody(registerNurseSchema),
  asyncHandler(async (req, res) => {
    res.status(201).json(await authService.registerNurse(req.body));
  })
);

authRouter.post(
  '/register',
  requireAuth,
  requireRoles('ADMIN'),
  validateBody(adminRegisterSchema),
  asyncHandler(async (req, res) => {
    res.status(201).json(await authService.register(req.body));
  })
);

authRouter.get('/me', requireAuth, (req, res) => {
  res.json({ user: req.user });
});
