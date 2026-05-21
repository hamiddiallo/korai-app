import type { ConsultationStatus, EarSide, UrgencyLevel } from '@prisma/client';
import type { AiSummary, LegacyOrlCase } from '../../common/types.js';

export type ConsultationRecord = {
  id: string;
  externalAiCaseId?: string;
  patientId: string;
  createdByUserId: string;
  assignedSpecialistId?: string;
  earSide: EarSide;
  symptomIds: string[];
  symptomLabels: string[];
  medicalHistoryIds: string[];
  medicalHistoryLabels: string[];
  touchCheckIds: string[];
  touchCheckLabels: string[];
  touchObservations?: Record<string, string>;
  clinicalNotes?: string;
  clinicalNarrative: string;
  status: ConsultationStatus;
  urgency: UrgencyLevel;
  createdAt: string;
  updatedAt: string;
  aiResponse?: {
    rawJson: unknown;
    imageOpinion?: string | null;
    ragOpinion?: string | null;
    likelyDiagnosis?: string | null;
    confidenceLabel?: string | null;
    warnings: string[];
    sources: string[];
  };
};

export const toLegacyOrlCase = (consultation: ConsultationRecord): LegacyOrlCase => {
  const organizedAiSummary: AiSummary | undefined = consultation.aiResponse
    ? {
        imageOpinion: consultation.aiResponse.imageOpinion ?? undefined,
        ragOpinion: consultation.aiResponse.ragOpinion ?? undefined,
        likelyDiagnosis: consultation.aiResponse.likelyDiagnosis ?? undefined,
        confidenceLabel:
          (consultation.aiResponse.confidenceLabel as AiSummary['confidenceLabel']) ?? 'UNKNOWN',
        warnings: consultation.aiResponse.warnings,
        sources: consultation.aiResponse.sources,
        raw: consultation.aiResponse.rawJson
      }
    : undefined;

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
    status: consultation.status,
    urgency: consultation.urgency,
    createdAt: consultation.createdAt,
    updatedAt: consultation.updatedAt
  };
};
