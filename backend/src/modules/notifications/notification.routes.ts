import { Router } from 'express';
import { requireAuth } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { notificationController } from './notification.controller.js';

export const notificationRouter = Router();

notificationRouter.use(requireAuth);

notificationRouter.get(
  '/',
  asyncHandler((req, res) => notificationController.list(req, res))
);

notificationRouter.get(
  '/unread-count',
  asyncHandler((req, res) => notificationController.unreadCount(req, res))
);

notificationRouter.patch(
  '/:id/read',
  asyncHandler((req, res) => notificationController.markRead(req, res))
);

notificationRouter.post(
  '/read-all',
  asyncHandler((req, res) => notificationController.markAllRead(req, res))
);
