import { ConsultationStatus, EarSide, UrgencyLevel } from '@prisma/client';
import { notFound } from '../../common/errors/http-error.js';
import type { AuthenticatedUser } from '../../common/types.js';
import { aiService, extractAiFieldsFromRaw } from '../ai/ai.service.js';
import { patientDao } from '../patients/patient.dao.js';
import { consultationDao } from './consultation.dao.js';
import { toLegacyOrlCase } from './consultation.types.js';
import { expertiseService } from '../expertise/expertise.service.js';

type CreateInput = {
  createdByUserId: string;
  patientId: string;
  clinicalNarrative: string;
  clinicalNotes?: string;
  urgency: UrgencyLevel;
  earSide: EarSide;
  symptomIds?: string[];
  symptomLabels?: string[];
  medicalHistoryIds?: string[];
  medicalHistoryLabels?: string[];
  touchCheckIds?: string[];
  touchCheckLabels?: string[];
  touchObservations?: Record<string, string>;
  clientLocalId?: string;
  clientMutationId?: string;
};

const persistAiAndFinalize = async (
  consultationId: string,
  input: {
    createdByUserId: string;
    requestSpecialistReview: boolean;
    hadOtoscopicImage: boolean;
    viewerRole: AuthenticatedUser['role'];
  },
  rawJson: unknown
) => {
  const extract = extractAiFieldsFromRaw(rawJson, { hadOtoscopicImage: input.hadOtoscopicImage });
  const externalAiCaseId =
    rawJson && typeof rawJson === 'object' && 'case_id' in rawJson
      ? String((rawJson as { case_id: unknown }).case_id)
      : undefined;

  await consultationDao.createAiResponse(consultationId, rawJson, extract);

  const status = input.requestSpecialistReview
    ? ConsultationStatus.PENDING_SPECIALIST_REVIEW
    : ConsultationStatus.AI_COMPLETED;

  const updated = await consultationDao.update(consultationId, {
    externalAiCaseId,
    status
  });

  if (input.requestSpecialistReview && updated) {
    await expertiseService.createRequest(updated.id, input.createdByUserId);
  }

  const withAi = await consultationDao.findById(consultationId);
  return toLegacyOrlCase(withAi!, input.viewerRole);
};

const findExistingConsultationForClientKey = async (input: {
  createdByUserId: string;
  clientLocalId?: string;
  clientMutationId?: string;
}) => {
  if (input.clientMutationId) {
    const existing = await consultationDao.findByClientMutationId(
      input.createdByUserId,
      input.clientMutationId
    );
    if (existing) return existing;
  }

  if (input.clientLocalId) {
    const existing = await consultationDao.findByClientLocalId(
      input.createdByUserId,
      input.clientLocalId
    );
    if (existing) return existing;
  }

  return undefined;
};

export const consultationService = {
  async createDraft(input: CreateInput, viewerRole: AuthenticatedUser['role'] = 'NURSE') {
    const patient = await patientDao.findById(input.patientId);
    if (!patient) throw notFound('Patient introuvable');

    const existing = await findExistingConsultationForClientKey(input);
    if (existing) return toLegacyOrlCase(existing, viewerRole);

    const consultation = await consultationDao.create({
      ...input,
      status: ConsultationStatus.DRAFT
    });
    return toLegacyOrlCase(consultation, viewerRole);
  },

  /**
   * Analyse IA : image presente → /diagnose-separate ; sinon → /rag/analyze.
   */
  async submitDiagnosis(
    input: CreateInput & {
      image?: Express.Multer.File;
      showSources: boolean;
      requestSpecialistReview: boolean;
      viewerRole: AuthenticatedUser['role'];
    }
  ) {
    const patient = await patientDao.findById(input.patientId);
    if (!patient) throw notFound('Patient introuvable');

    const existing = await findExistingConsultationForClientKey(input);
    if (existing?.aiResponse) {
      return toLegacyOrlCase(existing, input.viewerRole);
    }

    const consultation =
      existing ??
      (await consultationDao.create({
        ...input,
        status: ConsultationStatus.PENDING_AI
      }));

    if (input.image) {
      await consultationDao.createOtoscopicImage({
        consultationId: consultation.id,
        earSide: input.earSide,
        mimeType: input.image.mimetype,
        fileName: input.image.originalname,
        byteSize: input.image.size
      });

      const rawJson = await aiService.diagnoseSeparate({
        image: input.image,
        symptoms: input.clinicalNarrative,
        showSources: input.showSources
      });

      return persistAiAndFinalize(
        consultation.id,
        {
          createdByUserId: input.createdByUserId,
          requestSpecialistReview: input.requestSpecialistReview,
          hadOtoscopicImage: true,
          viewerRole: input.viewerRole
        },
        rawJson
      );
    }

    const rawJson = await aiService.ragAnalyze({
      symptoms: input.clinicalNarrative,
      showSources: input.showSources
    });

    return persistAiAndFinalize(
      consultation.id,
      {
        createdByUserId: input.createdByUserId,
        requestSpecialistReview: input.requestSpecialistReview,
        hadOtoscopicImage: false,
        viewerRole: input.viewerRole
      },
      rawJson
    );
  },

  async listForUser(user: AuthenticatedUser) {
    const consultations = await consultationDao.list();
    const filtered =
      user.role === 'NURSE' || user.role === 'ADMIN'
        ? consultations
        : user.role === 'SPECIALIST'
          ? consultations.filter(
              (c) =>
                c.status === ConsultationStatus.PENDING_SPECIALIST_REVIEW ||
                c.assignedSpecialistId === user.id ||
                c.expertiseRequest?.assignedToUserId === user.id
            )
          : user.role === 'PATIENT'
            ? consultations.filter(
                (c) =>
                  c.createdByUserId === user.id ||
                  (user.linkedPatientId && c.patientId === user.linkedPatientId)
              )
            : consultations;

    return filtered.map((c) => toLegacyOrlCase(c, user.role));
  },

  async requestSpecialistReview(
    id: string,
    requestedByUserId: string,
    input?: { summaryNote?: string; noteAudio?: string },
    viewerRole: AuthenticatedUser['role'] = 'NURSE'
  ) {
    await expertiseService.createRequest(id, requestedByUserId, input);
    const updated = await consultationDao.findById(id);
    if (!updated) throw notFound('Cas introuvable');
    return toLegacyOrlCase(updated, viewerRole);
  },

  async completeSpecialistReview(
    id: string,
    specialistId: string,
    review: {
      decision: import('@prisma/client').ExpertDecision;
      comment?: string;
      correctedLikelyDiagnosis?: string;
      correctedRecommendation?: string;
      correctedClinicalSummary?: string;
    },
    viewerRole: AuthenticatedUser['role'] = 'SPECIALIST'
  ) {
    await expertiseService.submitReview(id, specialistId, review);
    const updated = await consultationDao.findById(id);
    if (!updated) throw notFound('Cas introuvable');
    return toLegacyOrlCase(updated, viewerRole);
  }
};
