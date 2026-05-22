import type { ExpertDecision, ExpertiseStatus } from '@prisma/client';

export type AiSummarySnapshot = {
  imageOpinion?: string;
  ragOpinion?: string;
  likelyDiagnosis?: string;
  confidenceLabel?: string;
  warnings: string[];
  sources: string[];
};

export type ExpertiseRecord = {
  id: string;
  consultationId: string;
  requestedByUserId: string;
  assignedToUserId?: string;
  status: ExpertiseStatus;
  decision?: ExpertDecision;
  comment?: string;
  correctedLikelyDiagnosis?: string;
  correctedRecommendation?: string;
  correctedClinicalSummary?: string;
  aiLikelyDiagnosisSnapshot?: string;
  aiConfidenceLabelSnapshot?: string;
  aiSummarySnapshot?: AiSummarySnapshot;
  summaryNote?: string;
  noteAudio?: string;
  reviewedAt?: string;
  createdAt: string;
  updatedAt: string;
};

export type EffectiveSummarySource =
  | 'AI'
  | 'EXPERT_VALIDATED'
  | 'EXPERT_CORRECTED'
  | 'EXPERT_SUBSTITUTE';

export type EffectiveSummary = {
  source: EffectiveSummarySource;
  likelyDiagnosis: string;
  recommendation?: string;
  clinicalSummary?: string;
  confidenceLabel: 'LOW' | 'MEDIUM' | 'HIGH' | 'UNKNOWN';
  expertValidated: boolean;
  /** Patient : masquer le detail clinique tant que le cycle n'est pas clos. */
  patientVisible: boolean;
  patientStatusLabel?: string;
};

export type ExpertiseReviewApi = {
  status: ExpertiseStatus;
  decision?: ExpertDecision;
  requestedAt: string;
  reviewedAt?: string;
  comment?: string;
  correctedLikelyDiagnosis?: string;
  correctedRecommendation?: string;
  correctedClinicalSummary?: string;
  assignedToUserId?: string;
  aiSnapshot?: AiSummarySnapshot;
  summaryNote?: string;
  noteAudio?: string;
};

export const buildAiSummarySnapshot = (ai: {
  imageOpinion?: string | null;
  ragOpinion?: string | null;
  likelyDiagnosis?: string | null;
  confidenceLabel?: string | null;
  warnings: string[];
  sources: string[];
}): AiSummarySnapshot => ({
  imageOpinion: ai.imageOpinion ?? undefined,
  ragOpinion: ai.ragOpinion ?? undefined,
  likelyDiagnosis: ai.likelyDiagnosis ?? undefined,
  confidenceLabel: ai.confidenceLabel ?? undefined,
  warnings: ai.warnings,
  sources: ai.sources
});
