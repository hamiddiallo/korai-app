import cors from 'cors';
import express from 'express';
import { adminRouter } from './admin/admin.routes.js';
import { authRouter } from './auth/auth.routes.js';
import { caseRouter } from './cases/case.routes.js';
import { clinicalRouter } from './clinical/clinical.routes.js';
import { errorMiddleware } from './common/error.middleware.js';
import { env } from './config/env.js';
import { patientRouter } from './patients/patient.routes.js';

export const createApp = () => {
  const app = express();

  app.use(cors({ origin: env.CORS_ORIGIN === '*' ? true : env.CORS_ORIGIN }));
  app.use(express.json({ limit: '1mb' }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'korai-backend' });
  });

  app.use('/auth', authRouter);
  app.use('/admin', adminRouter);
  app.use('/clinical-items', clinicalRouter);
  app.use('/patients', patientRouter);
  app.use('/cases', caseRouter);

  app.use(errorMiddleware);

  return app;
};
