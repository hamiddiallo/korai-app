import { Router } from 'express';
import { requireAuth } from '../../common/middleware/auth.middleware.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { chatController } from './chat.controller.js';
import {
  createConversationSchema,
  sendMessageSchema,
  updateConversationSchema
} from './chat.schemas.js';

export const chatRouter = Router();

chatRouter.use(requireAuth);

chatRouter.get(
  '/conversations',
  asyncHandler((req, res) => chatController.listConversations(req, res))
);

chatRouter.post(
  '/conversations',
  validateBody(createConversationSchema),
  asyncHandler((req, res) => chatController.createConversation(req, res))
);

chatRouter.get(
  '/conversations/:id',
  asyncHandler((req, res) => chatController.getConversation(req, res))
);

chatRouter.patch(
  '/conversations/:id',
  validateBody(updateConversationSchema),
  asyncHandler((req, res) => chatController.updateConversation(req, res))
);

chatRouter.get(
  '/conversations/:id/messages',
  asyncHandler((req, res) => chatController.listMessages(req, res))
);

chatRouter.post(
  '/conversations/:id/messages',
  validateBody(sendMessageSchema),
  asyncHandler((req, res) => chatController.sendMessage(req, res))
);

chatRouter.post(
  '/conversations/:id/messages/:messageId/retry',
  asyncHandler((req, res) => chatController.retryMessage(req, res))
);

chatRouter.patch(
  '/conversations/:id/read',
  asyncHandler((req, res) => chatController.markRead(req, res))
);
