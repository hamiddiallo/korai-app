import { Router } from 'express';
import { requireAuth } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import { chatSchema, ragAnalyzeSchema } from './ai.schemas.js';
import { aiController } from './ai.controller.js';

export const aiRouter = Router();

aiRouter.use(requireAuth);

aiRouter.post('/chat', validateBody(chatSchema), asyncHandler((req, res) => aiController.chat(req, res)));

aiRouter.post(
  '/rag/analyze',
  validateBody(ragAnalyzeSchema),
  asyncHandler((req, res) => aiController.ragAnalyze(req, res))
);
