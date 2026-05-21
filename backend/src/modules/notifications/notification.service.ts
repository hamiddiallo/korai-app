import { notificationDao } from './notification.dao.js';

export const notificationService = {
  async getPendingExpertiseCount(userId: string) {
    return notificationDao.countPendingExpertiseForUser(userId);
  }
};
