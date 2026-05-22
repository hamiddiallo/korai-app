import type { ExpertDecision, ExpertiseStatus, Prisma } from '@prisma/client';
import type { AiSummary, LegacyOrlCase, Role } from '../../common/types.js';
import { buildEffectiveSummary, toExpertiseReviewApi } from '../expertise/effective-summary.js';
import type { AiSummarySnapshot, ExpertiseRecord } from '../expertise/expertise.types.js';
import type { ConsultationRecord } from './consultation.types.js';

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const parseAiSummarySnapshot = (value: Prisma.JsonValue | null | undefined): AiSummarySnapshot | undefined => {
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

export const mapExpertiseFromRow = (row: {
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
  aiSummarySnapshot: Prisma.JsonValue | null;
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

export type ConsultationWithExpertise = ConsultationRecord & {
  expertiseRequest?: ExpertiseRecord;
};

const toOrganizedAiSummary = (consultation: ConsultationRecord): AiSummary | undefined => {
  if (!consultation.aiResponse) return undefined;
  return {
    imageOpinion: consultation.aiResponse.imageOpinion ?? undefined,
    ragOpinion: consultation.aiResponse.ragOpinion ?? undefined,
    likelyDiagnosis: consultation.aiResponse.likelyDiagnosis ?? undefined,
    confidenceLabel:
      (consultation.aiResponse.confidenceLabel as AiSummary['confidenceLabel']) ?? 'UNKNOWN',
    warnings: consultation.aiResponse.warnings,
    sources: consultation.aiResponse.sources,
    raw: consultation.aiResponse.rawJson
  };
};

export const toLegacyOrlCaseFromRecord = (
  consultation: ConsultationWithExpertise,
  viewerRole: Role = 'NURSE'
): LegacyOrlCase => {
  const organizedAiSummary = toOrganizedAiSummary(consultation);
  const expertise = consultation.expertiseRequest;

  return {
    id: consultation.id,
    externalAiCaseId: consultation.externalAiCaseId,
    patientId: consultation.patientId,
    createdByUserId: consultation.createdByUserId,
    assignedSpecialistId: consultation.assignedSpecialistId,
    earSide: consultation.earSide,
    symptoms: consultation.clinicalNarrative,
    clinicalNotes: consultation.clinicalNotes,
    symptomIds: consultation.symptomIds,
    symptomLabels: consultation.symptomLabels,
    medicalHistoryIds: consultation.medicalHistoryIds,
    medicalHistoryLabels: consultation.medicalHistoryLabels,
    touchCheckIds: consultation.touchCheckIds,
    touchCheckLabels: consultation.touchCheckLabels,
    touchObservations: consultation.touchObservations,
    aiResponse: consultation.aiResponse?.rawJson,
    organizedAiSummary,
    expertiseReview: expertise ? toExpertiseReviewApi(expertise) : undefined,
    effectiveSummary: buildEffectiveSummary({
      consultationStatus: consultation.status,
      expertise,
      aiSummary: organizedAiSummary,
      viewerRole
    }),
    status: consultation.status,
    urgency: consultation.urgency,
    createdAt: consultation.createdAt,
    updatedAt: consultation.updatedAt
  };
};
