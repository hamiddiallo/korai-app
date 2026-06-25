import type { NotificationType, Prisma } from '@prisma/client';
import { prisma } from '../../common/prisma.js';

export type CreateNotificationInput = {
  recipientUserId: string;
  type: NotificationType;
  title: string;
  body: string;
  consultationId?: string;
  patientId?: string;
  data?: Prisma.InputJsonValue;
};

export const notificationDao = {
  async createMany(inputs: CreateNotificationInput[]) {
    if (inputs.length === 0) return;
    await prisma.notification.createMany({ data: inputs });
  },

  listForUser(userId: string, opts: { limit: number; before?: string }) {
    return prisma.notification.findMany({
      where: {
        recipientUserId: userId,
        ...(opts.before ? { createdAt: { lt: new Date(opts.before) } } : {})
      },
      orderBy: { createdAt: 'desc' },
      take: opts.limit
    });
  },

  countUnread(userId: string) {
    return prisma.notification.count({
      where: { recipientUserId: userId, isRead: false }
    });
  },

  async markRead(userId: string, id: string) {
    const result = await prisma.notification.updateMany({
      where: { id, recipientUserId: userId, isRead: false },
      data: { isRead: true, readAt: new Date() }
    });
    return result.count > 0;
  },

  async markAllRead(userId: string) {
    const result = await prisma.notification.updateMany({
      where: { recipientUserId: userId, isRead: false },
      data: { isRead: true, readAt: new Date() }
    });
    return result.count;
  }
};
