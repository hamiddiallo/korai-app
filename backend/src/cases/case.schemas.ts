import { z } from 'zod';

export const createAiCaseFieldsSchema = z.object({
  patientId: z.string().uuid(),
  symptoms: z.string().min(5),
  clinicalNotes: z.string().optional(),
  urgency: z.enum(['LOW', 'MEDIUM', 'HIGH']).default('MEDIUM'),
  showSources: z.coerce.boolean().default(true),
  requestSpecialistReview: z.coerce.boolean().default(false)
});

export const specialistReviewSchema = z.object({
  diagnosis: z.string().min(2),
  recommendation: z.string().min(2),
  specialistNotes: z.string().optional()
});
