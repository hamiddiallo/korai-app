import { ExpertDecision } from '@prisma/client';
import { z } from 'zod';

export const requestExpertiseSchema = z.object({
  summaryNote: z.string().optional(),
  noteAudio: z.string().optional()
});

export const submitExpertiseReviewSchema = z
  .object({
    decision: z.nativeEnum(ExpertDecision),
    comment: z.string().optional(),
    correctedLikelyDiagnosis: z.string().optional(),
    correctedRecommendation: z.string().optional(),
    correctedClinicalSummary: z.string().optional()
  })
  .superRefine((data, ctx) => {
    if (data.decision === ExpertDecision.CORRECTED) {
      if (!data.correctedLikelyDiagnosis?.trim()) {
        ctx.addIssue({
          code: 'custom',
          message: 'correctedLikelyDiagnosis est obligatoire pour une correction',
          path: ['correctedLikelyDiagnosis']
        });
      }
      if (!data.correctedClinicalSummary?.trim()) {
        ctx.addIssue({
          code: 'custom',
          message: 'correctedClinicalSummary est obligatoire pour une correction',
          path: ['correctedClinicalSummary']
        });
      }
    }
    if (data.decision === ExpertDecision.INSUFFICIENT) {
      if (!data.correctedClinicalSummary?.trim()) {
        ctx.addIssue({
          code: 'custom',
          message: 'correctedClinicalSummary est obligatoire lorsque l’IA est insuffisante',
          path: ['correctedClinicalSummary']
        });
      }
    }
  });
