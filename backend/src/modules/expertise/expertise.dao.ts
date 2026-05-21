import { ExpertiseStatus } from '@prisma/client';
import { prisma } from '../../common/prisma.js';

export const expertiseDao = {
  async findByConsultationId(consultationId: string) {
    return prisma.expertiseRequest.findUnique({ where: { consultationId } });
  },

  async upsertRequest(input: {
    consultationId: string;
    requestedByUserId: string;
    status?: ExpertiseStatus;
  }) {
    return prisma.expertiseRequest.upsert({
      where: { consultationId: input.consultationId },
      create: {
        consultationId: input.consultationId,
        requestedByUserId: input.requestedByUserId,
        status: input.status ?? ExpertiseStatus.PENDING
      },
      update: {
        requestedByUserId: input.requestedByUserId,
        status: input.status ?? ExpertiseStatus.PENDING
      }
    });
  },

  async completeReview(
    consultationId: string,
    assignedToUserId: string,
    review: { diagnosis: string; recommendation: string; specialistNotes?: string }
  ) {
    return prisma.expertiseRequest.update({
      where: { consultationId },
      data: {
        assignedToUserId,
        status: ExpertiseStatus.COMPLETED,
        diagnosis: review.diagnosis,
        recommendation: review.recommendation,
        specialistNotes: review.specialistNotes
      }
    });
  }
};
