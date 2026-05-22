import { ConsultationStatus, ExpertDecision, ExpertiseStatus } from '@prisma/client';
import { forbidden, notFound } from '../../common/errors/http-error.js';
import { HttpError } from '../../common/errors/http-error.js';
import { consultationDao } from '../consultations/consultation.dao.js';
import { expertiseDao } from './expertise.dao.js';
import { buildAiSummarySnapshot } from './expertise.types.js';

export const expertiseService = {
  async createRequest(
    consultationId: string,
    requestedByUserId: string,
    input?: { summaryNote?: string; noteAudio?: string }
  ) {
    const consultation = await consultationDao.findByIdWithExpertise(consultationId);
    if (!consultation) throw notFound('Consultation introuvable');

    if (!consultation.aiResponse) {
      throw new HttpError(
        409,
        'AI_RESPONSE_REQUIRED',
        'Une reponse IA doit exister avant de demander une expertise'
      );
    }

    if (consultation.expertiseRequest?.status === ExpertiseStatus.COMPLETED) {
      throw new HttpError(409, 'EXPERTISE_ALREADY_COMPLETED', 'Cette expertise est deja terminee');
    }

    const ai = consultation.aiResponse;
    const snapshot = buildAiSummarySnapshot(ai);

    const expertise = await expertiseDao.createOrRefreshRequest({
      consultationId,
      requestedByUserId,
      aiLikelyDiagnosisSnapshot: ai.likelyDiagnosis ?? 'Non déterminé',
      aiConfidenceLabelSnapshot: ai.confidenceLabel ?? 'UNKNOWN',
      aiSummarySnapshot: snapshot,
      summaryNote: input?.summaryNote,
      noteAudio: input?.noteAudio
    });

    await consultationDao.update(consultationId, {
      status: ConsultationStatus.PENDING_SPECIALIST_REVIEW
    });

    return expertise;
  },

  async listInbox() {
    const rows = await expertiseDao.listInbox();
    return rows.map((row) => ({
      expertise: {
        id: row.id,
        consultationId: row.consultationId,
        status: row.status,
        createdAt: row.createdAt.toISOString(),
        assignedToUserId: row.assignedToUserId
      },
      consultation: row.consultation,
      patient: row.consultation.patient
    }));
  },

  async assignToReview(consultationId: string, specialistId: string) {
    const expertise = await expertiseDao.findByConsultationId(consultationId);
    if (!expertise) throw notFound('Demande d expertise introuvable');

    if (expertise.status === ExpertiseStatus.COMPLETED) {
      throw new HttpError(409, 'EXPERTISE_ALREADY_COMPLETED', 'Expertise deja terminee');
    }

    if (expertise.status === ExpertiseStatus.IN_REVIEW && expertise.assignedToUserId !== specialistId) {
      throw forbidden('Ce dossier est deja pris en charge par un autre specialiste');
    }

    if (expertise.status !== ExpertiseStatus.PENDING && expertise.status !== ExpertiseStatus.IN_REVIEW) {
      throw new HttpError(409, 'INVALID_EXPERTISE_STATUS', 'Statut expertise invalide pour prise en charge');
    }

    const updated = await expertiseDao.assignToReview(consultationId, specialistId);
    await consultationDao.update(consultationId, { assignedSpecialistId: specialistId });
    return updated;
  },

  async submitReview(
    consultationId: string,
    specialistId: string,
    input: {
      decision: ExpertDecision;
      comment?: string;
      correctedLikelyDiagnosis?: string;
      correctedRecommendation?: string;
      correctedClinicalSummary?: string;
    }
  ) {
    const expertise = await expertiseDao.findByConsultationId(consultationId);
    if (!expertise) throw notFound('Demande d expertise introuvable');

    if (expertise.status !== ExpertiseStatus.IN_REVIEW) {
      throw new HttpError(
        409,
        'EXPERTISE_NOT_IN_REVIEW',
        'Le dossier doit etre en IN_REVIEW avant soumission (prise en charge obligatoire)'
      );
    }

    if (expertise.assignedToUserId !== specialistId) {
      throw forbidden('Seul le specialiste assigne peut soumettre cet avis');
    }

    const completed = await expertiseDao.completeReview(consultationId, specialistId, input);

    await consultationDao.update(consultationId, {
      assignedSpecialistId: specialistId,
      status: ConsultationStatus.SPECIALIST_COMPLETED
    });

    return completed;
  },

  /** @deprecated Utiliser createRequest — conserve pour compat interne consultation.service */
  async requestReview(consultationId: string, requestedByUserId: string) {
    return this.createRequest(consultationId, requestedByUserId);
  }
};
