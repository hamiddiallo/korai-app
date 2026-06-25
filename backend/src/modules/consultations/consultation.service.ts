import { ConsultationStatus, EarSide, UrgencyLevel } from '@prisma/client';
import { forbidden, notFound } from '../../common/errors/http-error.js';
import type { AuthenticatedUser } from '../../common/types.js';
import { aiService, describeAiError, extractAiFieldsFromRaw } from '../ai/ai.service.js';
import { clinicalReferenceDao } from '../clinical-reference/clinical-reference.dao.js';
import { patientDao } from '../patients/patient.dao.js';
import { consultationDao } from './consultation.dao.js';
import { computeUrgency } from './urgency.js';
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
  clinicalFingerprint?: string;
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
    status,
    aiErrorCode: null,
    aiErrorMessage: null
  });

  if (input.requestSpecialistReview && updated) {
    await expertiseService.createRequest(updated.id, input.createdByUserId);
  }

  const withAi = await consultationDao.findById(consultationId);
  return toLegacyOrlCase(withAi!, input.viewerRole);
};

/**
 * Réutilise la réponse IA d'une consultation source identique (même empreinte,
 * sans image) sur la consultation cible — aucun appel au modèle IA.
 */
const persistReusedAiResponse = async (
  targetConsultationId: string,
  source: NonNullable<Awaited<ReturnType<typeof consultationDao.findReusableByFingerprint>>>,
  input: {
    createdByUserId: string;
    requestSpecialistReview: boolean;
    viewerRole: AuthenticatedUser['role'];
  },
  options?: { extraWarning?: string }
) => {
  await consultationDao.cloneAiResponse(source.aiResponse!, targetConsultationId, options);

  const status = input.requestSpecialistReview
    ? ConsultationStatus.PENDING_SPECIALIST_REVIEW
    : ConsultationStatus.AI_COMPLETED;

  const updated = await consultationDao.update(targetConsultationId, {
    status,
    externalAiCaseId: source.externalAiCaseId,
    aiErrorCode: null,
    aiErrorMessage: null
  });

  if (input.requestSpecialistReview && updated) {
    await expertiseService.createRequest(updated.id, input.createdByUserId);
  }

  const withAi = await consultationDao.findById(targetConsultationId);
  return toLegacyOrlCase(withAi!, input.viewerRole);
};

/**
 * Repli sur échec IA : avant de marquer AI_FAILED, on cherche une consultation
 * cliniquement équivalente (même empreinte) déjà analysée et on réutilise sa
 * réponse. Couvre aussi les consultations AVEC image (dont l'IA était la seule
 * source). Si aucune équivalence, on persiste l'échec normalement.
 */
const persistAiFailureOrReuse = async (
  consultationId: string,
  clinicalFingerprint: string | undefined,
  error: unknown,
  input: {
    createdByUserId: string;
    requestSpecialistReview: boolean;
    viewerRole: AuthenticatedUser['role'];
  }
) => {
  if (clinicalFingerprint) {
    const target = await consultationDao.findById(consultationId);
    const reusable = target
      ? await consultationDao.findReusableByFingerprint(clinicalFingerprint, {
          id: consultationId,
          earSide: target.earSide,
          symptomIds: target.symptomIds,
          medicalHistoryIds: target.medicalHistoryIds
        })
      : undefined;
    if (reusable?.aiResponse) {
      return persistReusedAiResponse(consultationId, reusable, input, {
        extraWarning:
          "Service IA momentanément indisponible : réponse réutilisée d'une consultation cliniquement équivalente."
      });
    }
  }
  return persistAiFailure(consultationId, error, input.viewerRole);
};

/**
 * Persiste un échec d'analyse IA sans laisser la consultation orpheline en
 * PENDING_AI : statut AI_FAILED + code/message d'erreur exploitables côté UI.
 * Ne lève pas : la consultation reste sauvegardée et l'analyse est rejouable.
 */
const persistAiFailure = async (
  consultationId: string,
  error: unknown,
  viewerRole: AuthenticatedUser['role']
) => {
  const { code, message } = describeAiError(error);
  await consultationDao.update(consultationId, {
    status: ConsultationStatus.AI_FAILED,
    aiErrorCode: code,
    aiErrorMessage: message
  });
  const withError = await consultationDao.findById(consultationId);
  return toLegacyOrlCase(withError!, viewerRole);
};

/**
 * Niveau d'urgence calculé automatiquement à partir des scores de danger des
 * symptômes et antécédents sélectionnés (le serveur fait autorité).
 */
const resolveUrgency = async (
  symptomIds?: string[],
  medicalHistoryIds?: string[]
): Promise<UrgencyLevel> => {
  const symIds = symptomIds ?? [];
  const histIds = medicalHistoryIds ?? [];
  const scores = await clinicalReferenceDao.dangerScoresByIds([
    ...new Set([...symIds, ...histIds])
  ]);
  const symptomScores = symIds.map((id) => scores.get(id) ?? 0);
  const historyScores = histIds.map((id) => scores.get(id) ?? 0);
  return computeUrgency(symptomScores, historyScores);
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
      urgency: await resolveUrgency(input.symptomIds, input.medicalHistoryIds),
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
      imageDescription?: string;
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

    const urgency = await resolveUrgency(input.symptomIds, input.medicalHistoryIds);
    const consultation = existing
      ? // Draft réutilisé : on recalcule l'urgence (les symptômes ont pu changer
        // depuis la création du brouillon) pour garder le serveur autoritaire.
        await consultationDao.update(existing.id, { urgency })
      : await consultationDao.create({
          ...input,
          urgency,
          status: ConsultationStatus.PENDING_AI
        });

    if (input.image || (input.imageDescription && input.imageDescription.trim().length > 0)) {
      await consultationDao.createOtoscopicImage({
        consultationId: consultation.id,
        earSide: input.earSide,
        mimeType: input.image?.mimetype ?? 'text/plain',
        fileName: input.image?.originalname,
        byteSize: input.image?.size,
        description: input.imageDescription
      });

      if (input.image) {
        try {
          const rawJson = await aiService.diagnoseSeparate({
            image: input.image,
            symptoms: input.clinicalNarrative,
            showSources: input.showSources
          });

          return await persistAiAndFinalize(
            consultation.id,
            {
              createdByUserId: input.createdByUserId,
              requestSpecialistReview: input.requestSpecialistReview,
              hadOtoscopicImage: true,
              viewerRole: input.viewerRole
            },
            rawJson
          );
        } catch (error) {
          return persistAiFailureOrReuse(
            consultation.id,
            input.clinicalFingerprint,
            error,
            {
              createdByUserId: input.createdByUserId,
              requestSpecialistReview: input.requestSpecialistReview,
              viewerRole: input.viewerRole
            }
          );
        }
      }
    }

    // Déduplication : si une consultation sans image, déjà analysée, partage la
    // même empreinte clinique, on réutilise sa réponse IA sans appeler le modèle.
    if (input.clinicalFingerprint) {
      const reusable = await consultationDao.findReusableByFingerprint(
        input.clinicalFingerprint,
        {
          id: consultation.id,
          earSide: input.earSide,
          symptomIds: input.symptomIds ?? [],
          medicalHistoryIds: input.medicalHistoryIds ?? []
        }
      );
      if (reusable?.aiResponse) {
        return persistReusedAiResponse(consultation.id, reusable, {
          createdByUserId: input.createdByUserId,
          requestSpecialistReview: input.requestSpecialistReview,
          viewerRole: input.viewerRole
        });
      }
    }

    try {
      const rawJson = await aiService.ragAnalyze({
        symptoms: input.clinicalNarrative,
        showSources: input.showSources
      });

      return await persistAiAndFinalize(
        consultation.id,
        {
          createdByUserId: input.createdByUserId,
          requestSpecialistReview: input.requestSpecialistReview,
          hadOtoscopicImage: false,
          viewerRole: input.viewerRole
        },
        rawJson
      );
    } catch (error) {
      return persistAiFailureOrReuse(
        consultation.id,
        input.clinicalFingerprint,
        error,
        {
          createdByUserId: input.createdByUserId,
          requestSpecialistReview: input.requestSpecialistReview,
          viewerRole: input.viewerRole
        }
      );
    }
  },

  /**
   * Rejoue l'analyse IA d'une consultation en échec (statut AI_FAILED ou
   * PENDING_AI bloqué). L'image otoscopique n'étant pas conservée côté serveur,
   * le retry s'appuie sur l'analyse RAG du récit clinique.
   */
  async retryDiagnosis(id: string, user: AuthenticatedUser) {
    const viewerRole = user.role;
    const consultation = await consultationDao.findById(id);
    if (!consultation) throw notFound('Consultation introuvable');

    // Contrôle d'appartenance : un patient ne peut relancer que ses propres cas.
    if (user.role === 'PATIENT') {
      const owns =
        consultation.createdByUserId === user.id ||
        (user.linkedPatientId && consultation.patientId === user.linkedPatientId);
      if (!owns) throw forbidden('Accès refusé à cette consultation.');
    }

    if (consultation.aiResponse) {
      // Analyse déjà aboutie : on renvoie l'existant (idempotent).
      return toLegacyOrlCase(consultation, viewerRole);
    }

    await consultationDao.update(id, {
      status: ConsultationStatus.PENDING_AI,
      aiErrorCode: null,
      aiErrorMessage: null
    });

    try {
      const rawJson = await aiService.ragAnalyze({
        symptoms: consultation.clinicalNarrative,
        showSources: true
      });

      return await persistAiAndFinalize(
        id,
        {
          createdByUserId: consultation.createdByUserId,
          requestSpecialistReview: false,
          // Retry = analyse RAG texte uniquement (l'image n'est pas conservée) :
          // on ne présente pas le résultat comme un diagnostic sur image.
          hadOtoscopicImage: false,
          viewerRole
        },
        rawJson
      );
    } catch (error) {
      return persistAiFailureOrReuse(id, consultation.clinicalFingerprint, error, {
        createdByUserId: consultation.createdByUserId,
        requestSpecialistReview: false,
        viewerRole
      });
    }
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
