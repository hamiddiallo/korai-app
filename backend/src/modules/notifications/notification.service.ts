import { notificationDao, type CreateNotificationInput } from './notification.dao.js';

const DEFAULT_LIMIT = 30;
const MAX_LIMIT = 100;

export const notificationService = {
  /**
   * Émission tolérante aux pannes : la création de notifications ne doit JAMAIS
   * faire échouer le flux métier (expertise, validation…). On filtre les
   * destinataires vides et on avale les erreurs (best-effort).
   */
  async emit(inputs: CreateNotificationInput[] | CreateNotificationInput) {
    const list = Array.isArray(inputs) ? inputs : [inputs];
    const valid = list.filter((n) => n.recipientUserId);
    if (valid.length === 0) return;
    try {
      await notificationDao.createMany(valid);
    } catch (error) {
      console.error('[notifications] emit failed', error);
    }
  },

  list(userId: string, opts?: { limit?: number; before?: string }) {
    const limit = Math.min(Math.max(opts?.limit ?? DEFAULT_LIMIT, 1), MAX_LIMIT);
    return notificationDao.listForUser(userId, { limit, before: opts?.before });
  },

  countUnread(userId: string) {
    return notificationDao.countUnread(userId);
  },

  markRead(userId: string, id: string) {
    return notificationDao.markRead(userId, id);
  },

  markAllRead(userId: string) {
    return notificationDao.markAllRead(userId);
  }
};
