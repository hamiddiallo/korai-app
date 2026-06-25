import type { Request, Response } from 'express';
import { notificationService } from './notification.service.js';

export const notificationController = {
  async list(req: Request, res: Response) {
    const limit = Number(req.query.limit) || undefined;
    const before = typeof req.query.before === 'string' ? req.query.before : undefined;
    const notifications = await notificationService.list(req.user!.id, { limit, before });
    res.json({ notifications });
  },

  async unreadCount(req: Request, res: Response) {
    res.json({ count: await notificationService.countUnread(req.user!.id) });
  },

  async markRead(req: Request, res: Response) {
    const ok = await notificationService.markRead(req.user!.id, String(req.params.id));
    res.json({ ok });
  },

  async markAllRead(req: Request, res: Response) {
    const count = await notificationService.markAllRead(req.user!.id);
    res.json({ count });
  }
};
