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
  createdAt: Date;
  updatedAt: Date;
  aiResponse?: {
    rawJson: Prisma.JsonValue;
    imageOpinion: string | null;
    ragOpinion: string | null;
    likelyDiagnosis: string | null;
    confidenceLabel: string | null;
    warnings: string[];
    sources: string[];
  } | null;
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
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString(),
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
  expertiseRequest: row.expertiseRequest ? mapExpertiseFromRow(row.expertiseRequest) : undefined
});

const includeRelations = {
  aiResponse: true,
  expertiseRequest: true
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
        touchObservations: input.touchObservations ?? undefined
      },
      include: includeRelations
    });
    return mapConsultation(row);
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
      orderBy: { updatedAt: 'desc' },
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
  }
};
