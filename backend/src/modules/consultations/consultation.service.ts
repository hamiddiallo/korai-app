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
};

const persistAiAndFinalize = async (
  consultationId: string,
  input: {
    createdByUserId: string;
    requestSpecialistReview: boolean;
    hadOtoscopicImage: boolean;
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
    await expertiseService.requestReview(updated.id, input.createdByUserId);
  }

  const withAi = await consultationDao.findById(consultationId);
  return toLegacyOrlCase(withAi!);
};

export const consultationService = {
  async createDraft(input: CreateInput) {
    const patient = await patientDao.findById(input.patientId);
    if (!patient) throw notFound('Patient introuvable');

    const consultation = await consultationDao.create({
      ...input,
      status: ConsultationStatus.DRAFT
    });
    return toLegacyOrlCase(consultation);
  },

  /**
   * Analyse IA : image presente → /diagnose-separate ; sinon → /rag/analyze.
   */
  async submitDiagnosis(
    input: CreateInput & {
      image?: Express.Multer.File;
      showSources: boolean;
      requestSpecialistReview: boolean;
    }
  ) {
    const patient = await patientDao.findById(input.patientId);
    if (!patient) throw notFound('Patient introuvable');

    const consultation = await consultationDao.create({
      ...input,
      status: ConsultationStatus.PENDING_AI
    });

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

      return persistAiAndFinalize(consultation.id, {
        createdByUserId: input.createdByUserId,
        requestSpecialistReview: input.requestSpecialistReview,
        hadOtoscopicImage: true
      }, rawJson);
    }

    const rawJson = await aiService.ragAnalyze({
      symptoms: input.clinicalNarrative,
      showSources: input.showSources
    });

    return persistAiAndFinalize(consultation.id, { ...input, hadOtoscopicImage: false }, rawJson);
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
                c.assignedSpecialistId === user.id
            )
          : user.role === 'PATIENT'
            ? consultations.filter(
                (c) =>
                  c.createdByUserId === user.id ||
                  (user.linkedPatientId && c.patientId === user.linkedPatientId)
              )
            : consultations;

    return filtered.map(toLegacyOrlCase);
  },

  async requestSpecialistReview(id: string, requestedByUserId: string) {
    const current = await consultationDao.findById(id);
    if (!current) throw notFound('Cas introuvable');

    await expertiseService.requestReview(id, requestedByUserId);
    const updated = await consultationDao.update(id, {
      status: ConsultationStatus.PENDING_SPECIALIST_REVIEW
    });
    return toLegacyOrlCase(updated!);
  },

  async completeSpecialistReview(
    id: string,
    specialistId: string,
    review: { diagnosis: string; recommendation: string; specialistNotes?: string }
  ) {
    const current = await consultationDao.findById(id);
    if (!current) throw notFound('Cas introuvable');

    await expertiseService.completeReview(id, specialistId, review);
    const updated = await consultationDao.update(id, {
      assignedSpecialistId: specialistId,
      status: ConsultationStatus.SPECIALIST_COMPLETED
    });
    return toLegacyOrlCase(updated!);
  }
};
