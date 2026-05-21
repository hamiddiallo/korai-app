import { ExpertiseStatus } from '@prisma/client';
import { expertiseDao } from './expertise.dao.js';

export const expertiseService = {
  async requestReview(consultationId: string, requestedByUserId: string) {
    return expertiseDao.upsertRequest({
      consultationId,
      requestedByUserId,
      status: ExpertiseStatus.PENDING
    });
  },

  async completeReview(
    consultationId: string,
    specialistId: string,
    review: { diagnosis: string; recommendation: string; specialistNotes?: string }
  ) {
    const existing = await expertiseDao.findByConsultationId(consultationId);
    if (!existing) {
      await expertiseDao.upsertRequest({
        consultationId,
        requestedByUserId: specialistId,
        status: ExpertiseStatus.IN_REVIEW
      });
    }
    return expertiseDao.completeReview(consultationId, specialistId, review);
  }
};
