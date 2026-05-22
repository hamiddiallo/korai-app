import { ConsultationStatus, ExpertDecision, ExpertiseStatus } from '@prisma/client';
import type { AiSummary } from '../../common/types.js';
import type {
  EffectiveSummary,
  ExpertiseRecord,
  ExpertiseReviewApi
} from './expertise.types.js';

type ViewerRole = 'NURSE' | 'SPECIALIST' | 'ADMIN' | 'PATIENT';

const normalizeConfidence = (value?: string | null): EffectiveSummary['confidenceLabel'] => {
  const upper = (value ?? 'UNKNOWN').toUpperCase();
  if (upper === 'HIGH' || upper === 'MEDIUM' || upper === 'LOW') return upper;
  return 'UNKNOWN';
};

const patientCycleClosed = (
  consultationStatus: ConsultationStatus,
  expertise?: ExpertiseRecord
): boolean =>
  consultationStatus === ConsultationStatus.SPECIALIST_COMPLETED &&
  expertise?.status === ExpertiseStatus.COMPLETED;

export const buildEffectiveSummary = (input: {
  consultationStatus: ConsultationStatus;
  expertise?: ExpertiseRecord;
  aiSummary?: AiSummary;
  viewerRole: ViewerRole;
}): EffectiveSummary => {
  const { consultationStatus, expertise, aiSummary, viewerRole } = input;
  const aiDiagnosis = aiSummary?.likelyDiagnosis?.trim() || 'Non déterminé';
  const aiConfidence = normalizeConfidence(aiSummary?.confidenceLabel);

  if (viewerRole === 'PATIENT' && !patientCycleClosed(consultationStatus, expertise)) {
    return {
      source: 'AI',
      likelyDiagnosis: 'Analyse en cours',
      confidenceLabel: 'UNKNOWN',
      expertValidated: false,
      patientVisible: false,
      patientStatusLabel: 'Votre consultation est en cours d’analyse par un spécialiste.'
    };
  }

  if (!expertise || expertise.status !== ExpertiseStatus.COMPLETED || !expertise.decision) {
    return {
      source: 'AI',
      likelyDiagnosis: aiDiagnosis,
      recommendation: undefined,
      clinicalSummary: [aiSummary?.imageOpinion, aiSummary?.ragOpinion].filter(Boolean).join('\n') || undefined,
      confidenceLabel: aiConfidence,
      expertValidated: false,
      patientVisible: viewerRole !== 'PATIENT' || patientCycleClosed(consultationStatus, expertise)
    };
  }

  switch (expertise.decision) {
    case ExpertDecision.VALIDATED:
      return {
        source: 'EXPERT_VALIDATED',
        likelyDiagnosis: aiDiagnosis,
        recommendation: expertise.correctedRecommendation,
        clinicalSummary: [aiSummary?.imageOpinion, aiSummary?.ragOpinion].filter(Boolean).join('\n') || undefined,
        confidenceLabel: 'HIGH',
        expertValidated: true,
        patientVisible: true
      };

    case ExpertDecision.CORRECTED:
      return {
        source: 'EXPERT_CORRECTED',
        likelyDiagnosis: expertise.correctedLikelyDiagnosis?.trim() || 'Non déterminé',
        recommendation: expertise.correctedRecommendation,
        clinicalSummary: expertise.correctedClinicalSummary,
        confidenceLabel: 'HIGH',
        expertValidated: true,
        patientVisible: true
      };

    case ExpertDecision.INSUFFICIENT:
      return {
        source: 'EXPERT_SUBSTITUTE',
        likelyDiagnosis: expertise.correctedLikelyDiagnosis?.trim() || 'Indéterminé',
        recommendation: expertise.correctedRecommendation,
        clinicalSummary: expertise.correctedClinicalSummary,
        confidenceLabel: 'HIGH',
        expertValidated: true,
        patientVisible: true
      };

    default:
      return {
        source: 'AI',
        likelyDiagnosis: aiDiagnosis,
        confidenceLabel: aiConfidence,
        expertValidated: false,
        patientVisible: viewerRole !== 'PATIENT'
      };
  }
};

export const toExpertiseReviewApi = (expertise: ExpertiseRecord): ExpertiseReviewApi => ({
  status: expertise.status,
  decision: expertise.decision,
  requestedAt: expertise.createdAt,
  reviewedAt: expertise.reviewedAt,
  comment: expertise.comment,
  correctedLikelyDiagnosis: expertise.correctedLikelyDiagnosis,
  correctedRecommendation: expertise.correctedRecommendation,
  correctedClinicalSummary: expertise.correctedClinicalSummary,
  assignedToUserId: expertise.assignedToUserId,
  aiSnapshot: expertise.aiSummarySnapshot,
  summaryNote: expertise.summaryNote,
  noteAudio: expertise.noteAudio
});
