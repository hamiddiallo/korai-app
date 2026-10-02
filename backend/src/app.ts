import cors from 'cors';
import express from 'express';
import { corsOrigins, env } from './config/env.js';
import { errorMiddleware } from './common/errors/error.middleware.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { adminRouter } from './modules/admin/admin.routes.js';
import { clinicalReferenceRouter } from './modules/clinical-reference/clinical-reference.routes.js';
import { patientRouter } from './modules/patients/patient.routes.js';
import { consultationRouter } from './modules/consultations/consultation.routes.js';
import { aiRouter } from './modules/ai/ai.routes.js';
import { expertiseRouter } from './modules/expertise/expertise.routes.js';
import { chatRouter } from './modules/chat/chat.routes.js';
import { notificationRouter } from './modules/notifications/notification.routes.js';
import { registrationRouter } from './modules/registrations/registration.routes.js';

export const createApp = () => {
  const app = express();

  app.disable('x-powered-by');
  if (env.TRUST_PROXY > 0) app.set('trust proxy', env.TRUST_PROXY);
  app.use((_req, res, next) => {
    // En-têtes de sécurité de base (API JSON, pas de rendu HTML).
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    next();
  });
  app.use(cors({ origin: corsOrigins(env.CORS_ORIGIN) }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'korai-backend' });
  });

  app.use('/auth', authRouter);
  app.use('/admin', adminRouter);
  app.use('/clinical-items', clinicalReferenceRouter);
  app.use('/patients', patientRouter);
  app.use('/cases', consultationRouter);
  app.use('/expertise', expertiseRouter);
  app.use('/ai', aiRouter);
  app.use('/chat', chatRouter);
  app.use('/notifications', notificationRouter);
  app.use('/registrations', registrationRouter);

  app.use(errorMiddleware);

  return app;
};
