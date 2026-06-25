import type {
  ConsultationStatus,
  EarSide,
  Prisma,
  UrgencyLevel
} from '@prisma/client';
import { prisma } from '../../common/prisma.js';
import type { ConsultationRecord } from './consultation.types.js';
import type { AiResponseExtract } from '../ai/ai.service.js';
import { mapExpertiseFromRow } from './consultation.mapper.js';
import type { ExpertiseRecord } from '../expertise/expertise.types.js';

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const mapConsultation = (row: {
  id: string;
  externalAiCaseId: string | null;
  patientId: string;
  createdByUserId: string;
  assignedSpecialistId: string | null;
  earSide: EarSide;
  symptomIds: string[];
  symptomLabels: string[];
  medicalHistoryIds: string[];
  medicalHistoryLabels: string[];
  touchCheckIds: string[];
  touchCheckLabels: string[];
  touchObservations: Prisma.JsonValue;
  clinicalNotes: string | null;
  clinicalNarrative: string;
  status: ConsultationStatus;
  urgency: UrgencyLevel;
  aiErrorCode: string | null;
  aiErrorMessage: string | null;
  clinicalFingerprint: string | null;
  clientLocalId: string | null;
  clientMutationId: string | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt?: Date | null;
  aiResponse?: {
    rawJson: Prisma.JsonValue;
    imageOpinion: string | null;
    ragOpinion: string | null;
    likelyDiagnosis: string | null;
    confidenceLabel: string | null;
    warnings: string[];
    sources: string[];
  } | null;
  otoscopicImages?: {
    id: string;
    earSide: EarSide;
    mimeType: string;
    fileName: string | null;
    byteSize: number | null;
    description: string | null;
    createdAt: Date;
  }[];
  expertiseRequest?: Parameters<typeof mapExpertiseFromRow>[0] | null;
}): ConsultationRecord & { expertiseRequest?: ExpertiseRecord } => ({
  id: row.id,
  externalAiCaseId: nullable(row.externalAiCaseId),
  patientId: row.patientId,
  createdByUserId: row.createdByUserId,
  assignedSpecialistId: nullable(row.assignedSpecialistId),
  earSide: row.earSide,
  symptomIds: row.symptomIds,
  symptomLabels: row.symptomLabels,
  medicalHistoryIds: row.medicalHistoryIds,
  medicalHistoryLabels: row.medicalHistoryLabels,
  touchCheckIds: row.touchCheckIds,
  touchCheckLabels: row.touchCheckLabels,
  touchObservations:
    row.touchObservations && typeof row.touchObservations === 'object' && !Array.isArray(row.touchObservations)
      ? (row.touchObservations as Record<string, string>)
      : undefined,
  clinicalNotes: nullable(row.clinicalNotes),
  clinicalNarrative: row.clinicalNarrative,
  status: row.status,
  urgency: row.urgency,
  aiErrorCode: nullable(row.aiErrorCode),
  aiErrorMessage: nullable(row.aiErrorMessage),
  clinicalFingerprint: nullable(row.clinicalFingerprint),
  clientLocalId: nullable(row.clientLocalId),
  clientMutationId: nullable(row.clientMutationId),
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
  deletedAt: row.deletedAt?.toISOString(),
  aiResponse: row.aiResponse
    ? {
        rawJson: row.aiResponse.rawJson,
        imageOpinion: row.aiResponse.imageOpinion,
        ragOpinion: row.aiResponse.ragOpinion,
        likelyDiagnosis: row.aiResponse.likelyDiagnosis,
        confidenceLabel: row.aiResponse.confidenceLabel,
        warnings: row.aiResponse.warnings,
        sources: row.aiResponse.sources
      }
    : undefined,
  otoscopicImages: row.otoscopicImages?.map(img => ({
    id: img.id,
    earSide: img.earSide,
    mimeType: img.mimeType,
    fileName: nullable(img.fileName),
    byteSize: nullable(img.byteSize),
    description: nullable(img.description),
    createdAt: img.createdAt.toISOString()
  })),
  expertiseRequest: row.expertiseRequest ? mapExpertiseFromRow(row.expertiseRequest) : undefined
});

const includeRelations = {
  aiResponse: true,
  expertiseRequest: true,
  otoscopicImages: true
} as const;

export const consultationDao = {
  async create(input: {
    patientId: string;
    createdByUserId: string;
    earSide: EarSide;
    clinicalNarrative: string;
    clinicalNotes?: string;
    status: ConsultationStatus;
    urgency: UrgencyLevel;
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
  }) {
    const row = await prisma.consultation.create({
      data: {
        patientId: input.patientId,
        createdByUserId: input.createdByUserId,
        earSide: input.earSide,
        clinicalNarrative: input.clinicalNarrative,
        clinicalNotes: input.clinicalNotes,
        status: input.status,
        urgency: input.urgency,
        symptomIds: input.symptomIds ?? [],
        symptomLabels: input.symptomLabels ?? [],
        medicalHistoryIds: input.medicalHistoryIds ?? [],
        medicalHistoryLabels: input.medicalHistoryLabels ?? [],
        touchCheckIds: input.touchCheckIds ?? [],
        touchCheckLabels: input.touchCheckLabels ?? [],
        touchObservations: input.touchObservations ?? undefined,
        clientLocalId: input.clientLocalId,
        clientMutationId: input.clientMutationId,
        clinicalFingerprint: input.clinicalFingerprint
      },
      include: includeRelations
    });
    return mapConsultation(row);
  },

  /**
   * Cherche une consultation **sans image**, déjà analysée (AI_COMPLETED), de
   * même empreinte clinique — afin de réutiliser sa réponse IA sans réinterroger
   * le modèle. Exclut la consultation courante et les éléments supprimés.
   *
   * Validation serveur anti-collision : on ne réutilise une source que si ses
   * caractéristiques cliniques structurées (côté + symptômes + antécédents)
   * correspondent réellement à la cible — l'empreinte étant calculée côté client,
   * on ne se fie pas au seul hash pour cloner une réponse entre patients.
   */
  async findReusableByFingerprint(
    clinicalFingerprint: string,
    target: {
      id: string;
      earSide: EarSide;
      symptomIds: string[];
      medicalHistoryIds: string[];
    }
  ) {
    const rows = await prisma.consultation.findMany({
      where: {
        clinicalFingerprint,
        deletedAt: null,
        status: 'AI_COMPLETED',
        aiResponse: { isNot: null },
        otoscopicImages: { none: {} },
        id: { not: target.id }
      },
      orderBy: { createdAt: 'desc' },
      take: 5,
      include: includeRelations
    });
    const sameSet = (a: string[], b: string[]) => {
      if (a.length !== b.length) return false;
      const setB = new Set(b);
      return a.every((value) => setB.has(value));
    };
    const match = rows.find(
      (row) =>
        row.earSide === target.earSide &&
        sameSet(row.symptomIds, target.symptomIds) &&
        sameSet(row.medicalHistoryIds, target.medicalHistoryIds)
    );
    return match ? mapConsultation(match) : undefined;
  },

  /**
   * Clone la réponse IA d'une consultation source vers une cible, en marquant
   * explicitement la réutilisation (avertissement de traçabilité).
   */
  async cloneAiResponse(
    source: {
      rawJson: unknown;
      imageOpinion?: string | null;
      ragOpinion?: string | null;
      likelyDiagnosis?: string | null;
      confidenceLabel?: string | null;
      warnings: string[];
      sources: string[];
    },
    targetConsultationId: string,
    options?: { extraWarning?: string }
  ) {
    const reuseWarning =
      "Réponse IA réutilisée d'une consultation clinique identique (sans nouvelle analyse IA).";
    const warnings = [...source.warnings];
    if (!warnings.includes(reuseWarning)) warnings.unshift(reuseWarning);
    if (options?.extraWarning && !warnings.includes(options.extraWarning)) {
      warnings.unshift(options.extraWarning);
    }
    await prisma.aiResponse.create({
      data: {
        consultationId: targetConsultationId,
        rawJson: source.rawJson as Prisma.InputJsonValue,
        imageOpinion: source.imageOpinion ?? undefined,
        ragOpinion: source.ragOpinion ?? undefined,
        likelyDiagnosis: source.likelyDiagnosis ?? undefined,
        confidenceLabel: source.confidenceLabel ?? undefined,
        warnings,
        sources: source.sources
      }
    });
    return this.findById(targetConsultationId);
  },

  async findByClientLocalId(createdByUserId: string, clientLocalId: string) {
    const row = await prisma.consultation.findUnique({
      where: {
        createdByUserId_clientLocalId: {
          createdByUserId,
          clientLocalId
        }
      },
      include: includeRelations
    });
    return row ? mapConsultation(row) : undefined;
  },

  async findByClientMutationId(createdByUserId: string, clientMutationId: string) {
    const row = await prisma.consultation.findUnique({
      where: {
        createdByUserId_clientMutationId: {
          createdByUserId,
          clientMutationId
        }
      },
      include: includeRelations
    });
    return row ? mapConsultation(row) : undefined;
  },

  async findById(id: string) {
    const row = await prisma.consultation.findUnique({
      where: { id },
      include: includeRelations
    });
    return row ? mapConsultation(row) : undefined;
  },

  async findByIdWithExpertise(id: string) {
    return this.findById(id);
  },

  async list() {
    const rows = await prisma.consultation.findMany({
      where: { deletedAt: null },
      orderBy: { updatedAt: 'desc' },
      include: includeRelations
    });
    return rows.map(mapConsultation);
  },

  async listForPatient(patientId: string, includeDeleted = false) {
    const rows = await prisma.consultation.findMany({
      where: {
        patientId,
        ...(includeDeleted ? {} : { deletedAt: null })
      },
      orderBy: { createdAt: 'desc' },
      include: includeRelations
    });
    return rows.map(mapConsultation);
  },

  async update(
    id: string,
    patch: Partial<{
      externalAiCaseId: string;
      assignedSpecialistId: string;
      status: ConsultationStatus;
      urgency: UrgencyLevel;
      aiErrorCode: string | null;
      aiErrorMessage: string | null;
    }>
  ) {
    const row = await prisma.consultation.update({
      where: { id },
      data: patch,
      include: includeRelations
    });
    return mapConsultation(row);
  },

  async createOtoscopicImage(input: {
    consultationId: string;
    earSide: EarSide;
    mimeType: string;
    fileName?: string;
    byteSize?: number;
    description?: string;
  }) {
    return prisma.otoscopicImage.create({ data: input });
  },

  async createAiResponse(
    consultationId: string,
    rawJson: unknown,
    extract: AiResponseExtract
  ) {
    await prisma.aiResponse.create({
      data: {
        consultationId,
        rawJson: rawJson as Prisma.InputJsonValue,
        imageOpinion: extract.imageOpinion,
        ragOpinion: extract.ragOpinion,
        likelyDiagnosis: extract.likelyDiagnosis,
        confidenceLabel: extract.confidenceLabel,
        warnings: extract.warnings,
        sources: extract.sources
      }
    });
    return this.findById(consultationId);
  },

  async softDelete(id: string) {
    await prisma.$transaction(async (tx) => {
      const now = new Date();
      await tx.consultation.update({ where: { id }, data: { deletedAt: now } });
      await tx.otoscopicImage.updateMany({ where: { consultationId: id, deletedAt: null }, data: { deletedAt: now } });
      await tx.aiResponse.updateMany({ where: { consultationId: id, deletedAt: null }, data: { deletedAt: now } });
      await tx.expertiseRequest.updateMany({ where: { consultationId: id, deletedAt: null }, data: { deletedAt: now } });
    });
  },

  async restore(id: string) {
    await prisma.$transaction(async (tx) => {
      await tx.consultation.update({ where: { id }, data: { deletedAt: null } });
      await tx.otoscopicImage.updateMany({ where: { consultationId: id }, data: { deletedAt: null } });
      await tx.aiResponse.updateMany({ where: { consultationId: id }, data: { deletedAt: null } });
      await tx.expertiseRequest.updateMany({ where: { consultationId: id }, data: { deletedAt: null } });
    });
  },

  async listDeleted() {
    const rows = await prisma.consultation.findMany({
      where: { deletedAt: { not: null } },
      orderBy: { deletedAt: 'desc' },
      include: includeRelations
    });
    return rows.map(mapConsultation);
  }
};
