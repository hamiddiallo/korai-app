import type { ExpertDecision, ExpertiseStatus, Prisma } from '@prisma/client';
import { prisma } from '../../common/prisma.js';
import type { AiSummarySnapshot, ExpertiseRecord } from './expertise.types.js';

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const parseAiSummarySnapshot = (value: Prisma.JsonValue): AiSummarySnapshot | undefined => {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return undefined;
  const o = value as Record<string, unknown>;
  return {
    imageOpinion: o.imageOpinion?.toString(),
    ragOpinion: o.ragOpinion?.toString(),
    likelyDiagnosis: o.likelyDiagnosis?.toString(),
    confidenceLabel: o.confidenceLabel?.toString(),
    warnings: Array.isArray(o.warnings) ? o.warnings.map(String) : [],
    sources: Array.isArray(o.sources) ? o.sources.map(String) : []
  };
};

const mapExpertise = (row: {
  id: string;
  consultationId: string;
  requestedByUserId: string;
  assignedToUserId: string | null;
  status: ExpertiseStatus;
  decision: ExpertDecision | null;
  comment: string | null;
  correctedLikelyDiagnosis: string | null;
  correctedRecommendation: string | null;
  correctedClinicalSummary: string | null;
  aiLikelyDiagnosisSnapshot: string | null;
  aiConfidenceLabelSnapshot: string | null;
  aiSummarySnapshot: Prisma.JsonValue;
  summaryNote: string | null;
  noteAudio: string | null;
  reviewedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}): ExpertiseRecord => ({
  id: row.id,
  consultationId: row.consultationId,
  requestedByUserId: row.requestedByUserId,
  assignedToUserId: nullable(row.assignedToUserId),
  status: row.status,
  decision: row.decision ?? undefined,
  comment: nullable(row.comment),
  correctedLikelyDiagnosis: nullable(row.correctedLikelyDiagnosis),
  correctedRecommendation: nullable(row.correctedRecommendation),
  correctedClinicalSummary: nullable(row.correctedClinicalSummary),
  aiLikelyDiagnosisSnapshot: nullable(row.aiLikelyDiagnosisSnapshot),
  aiConfidenceLabelSnapshot: nullable(row.aiConfidenceLabelSnapshot),
  aiSummarySnapshot: parseAiSummarySnapshot(row.aiSummarySnapshot),
  summaryNote: nullable(row.summaryNote),
  noteAudio: nullable(row.noteAudio),
  reviewedAt: row.reviewedAt?.toISOString(),
  createdAt: row.createdAt.toISOString(),
  updatedAt: row.updatedAt.toISOString()
});

export const expertiseDao = {
  findByConsultationId(consultationId: string) {
    return prisma.expertiseRequest.findUnique({ where: { consultationId } }).then((r) => (r ? mapExpertise(r) : undefined));
  },

  async listInbox() {
    const rows = await prisma.expertiseRequest.findMany({
      where: { status: { in: ['PENDING', 'IN_REVIEW'] } },
      orderBy: { createdAt: 'asc' },
      include: {
        consultation: {
          include: {
            patient: true,
            aiResponse: true
          }
        }
      }
    });
    return rows;
  },

  async createOrRefreshRequest(input: {
    consultationId: string;
    requestedByUserId: string;
    aiLikelyDiagnosisSnapshot: string;
    aiConfidenceLabelSnapshot: string;
    aiSummarySnapshot: AiSummarySnapshot;
    summaryNote?: string;
    noteAudio?: string;
  }) {
    const row = await prisma.expertiseRequest.upsert({
      where: { consultationId: input.consultationId },
      create: {
        consultationId: input.consultationId,
        requestedByUserId: input.requestedByUserId,
        status: 'PENDING',
        aiLikelyDiagnosisSnapshot: input.aiLikelyDiagnosisSnapshot,
        aiConfidenceLabelSnapshot: input.aiConfidenceLabelSnapshot,
        aiSummarySnapshot: input.aiSummarySnapshot as Prisma.InputJsonValue,
        summaryNote: input.summaryNote,
        noteAudio: input.noteAudio
      },
      update: {
        requestedByUserId: input.requestedByUserId,
        status: 'PENDING',
        assignedToUserId: null,
        decision: null,
        comment: null,
        correctedLikelyDiagnosis: null,
        correctedRecommendation: null,
        correctedClinicalSummary: null,
        reviewedAt: null,
        aiLikelyDiagnosisSnapshot: input.aiLikelyDiagnosisSnapshot,
        aiConfidenceLabelSnapshot: input.aiConfidenceLabelSnapshot,
        aiSummarySnapshot: input.aiSummarySnapshot as Prisma.InputJsonValue,
        summaryNote: input.summaryNote,
        noteAudio: input.noteAudio
      }
    });
    return mapExpertise(row);
  },

  async assignToReview(consultationId: string, specialistId: string) {
    const row = await prisma.expertiseRequest.update({
      where: { consultationId },
      data: {
        status: 'IN_REVIEW',
        assignedToUserId: specialistId
      }
    });
    return mapExpertise(row);
  },

  async completeReview(
    consultationId: string,
    specialistId: string,
    data: {
      decision: ExpertDecision;
      comment?: string;
      correctedLikelyDiagnosis?: string;
      correctedRecommendation?: string;
      correctedClinicalSummary?: string;
    }
  ) {
    const row = await prisma.expertiseRequest.update({
      where: { consultationId },
      data: {
        status: 'COMPLETED',
        assignedToUserId: specialistId,
        decision: data.decision,
        comment: data.comment,
        correctedLikelyDiagnosis: data.correctedLikelyDiagnosis,
        correctedRecommendation: data.correctedRecommendation,
        correctedClinicalSummary: data.correctedClinicalSummary,
        reviewedAt: new Date()
      }
    });
    return mapExpertise(row);
  }
};
