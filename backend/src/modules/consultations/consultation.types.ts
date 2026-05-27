import type { ConsultationStatus, EarSide, UrgencyLevel } from '@prisma/client';
import type { AiSummary, LegacyOrlCase, Role } from '../../common/types.js';
import { toLegacyOrlCaseFromRecord, type ConsultationWithExpertise } from './consultation.mapper.js';

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
  clientLocalId?: string;
  clientMutationId?: string;
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

export const toLegacyOrlCase = (
  consultation: ConsultationRecord & { expertiseRequest?: ConsultationWithExpertise['expertiseRequest'] },
  viewerRole: Role = 'NURSE'
): LegacyOrlCase => toLegacyOrlCaseFromRecord(consultation, viewerRole);
