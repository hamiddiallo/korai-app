import { prisma } from '../../common/prisma.js';

/** Couche DAO notifications — extension future (push, email). */
export const notificationDao = {
  async countPendingExpertiseForUser(_userId: string) {
    return prisma.expertiseRequest.count({
      where: { status: 'PENDING' }
    });
  }
};
