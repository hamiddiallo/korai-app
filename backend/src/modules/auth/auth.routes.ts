import { Router } from 'express';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import { rateLimit } from '../../common/middleware/rate-limit.middleware.js';
import {
  adminRegisterSchema,
  loginSchema,
  refreshSchema,
  registerNurseSchema,
  registerSpecialistSchema,
  registerPatientSchema,
  updateProfileSchema,
  updatePasswordSchema
} from './auth.schemas.js';
import { authController } from './auth.controller.js';

export const authRouter = Router();

const FIFTEEN_MINUTES = 15 * 60 * 1000;

// Force brute : par adresse IP (large, plusieurs soignants peuvent partager la
// connexion d'un centre) et par compte visé.
const loginByIp = rateLimit({ name: 'login-ip', windowMs: FIFTEEN_MINUTES, max: 30 });
const loginByAccount = rateLimit({
  name: 'login-account',
  windowMs: FIFTEEN_MINUTES,
  max: 10,
  key: (req) => `${req.ip}:${String(req.body?.email ?? '').trim().toLowerCase()}`,
  message: 'Trop de tentatives de connexion pour ce compte. Réessayez dans 15 minutes.'
});
const registerByIp = rateLimit({ name: 'register', windowMs: 60 * 60 * 1000, max: 10 });
const refreshByIp = rateLimit({ name: 'refresh', windowMs: FIFTEEN_MINUTES, max: 60 });
const passwordByIp = rateLimit({ name: 'password', windowMs: FIFTEEN_MINUTES, max: 10 });

authRouter.post(
  '/login',
  loginByIp,
  loginByAccount,
  validateBody(loginSchema),
  asyncHandler((req, res) => authController.login(req, res))
);

// Renouvellement du jeton d'accès (30 min) avec le jeton de rafraîchissement.
authRouter.post(
  '/refresh',
  refreshByIp,
  validateBody(refreshSchema),
  asyncHandler((req, res) => authController.refresh(req, res))
);

authRouter.use('/register', registerByIp);

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
  '/register/specialist',
  validateBody(registerSpecialistSchema),
  asyncHandler((req, res) => authController.registerSpecialist(req, res))
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
  passwordByIp,
  requireAuth,
  validateBody(updatePasswordSchema),
  asyncHandler((req, res) => authController.updatePassword(req, res))
);
