import cors from 'cors';
import express from 'express';
import { env } from './config/env.js';
import { errorMiddleware } from './common/errors/error.middleware.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { adminRouter } from './modules/admin/admin.routes.js';
import { clinicalReferenceRouter } from './modules/clinical-reference/clinical-reference.routes.js';
import { patientRouter } from './modules/patients/patient.routes.js';
import { consultationRouter } from './modules/consultations/consultation.routes.js';

export const createApp = () => {
  const app = express();

  app.use(cors({ origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'korai-backend' });
  });

  app.use('/auth', authRouter);
  app.use('/admin', adminRouter);
  app.use('/clinical-items', clinicalReferenceRouter);
  app.use('/patients', patientRouter);
  app.use('/cases', consultationRouter);

  app.use(errorMiddleware);

  return app;
};
