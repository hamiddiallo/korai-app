import { EarSide, UrgencyLevel } from '@prisma/client';
import { z } from 'zod';

/** Parse tableaux envoyés en JSON string depuis multipart/form-data. */
const multipartStringArray = z.preprocess((value) => {
  if (value === undefined || value === '') return undefined;
  if (Array.isArray(value)) return value.map(String);
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) return parsed.map(String);
    } catch {
      return value
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean);
    }
  }
  return value;
}, z.array(z.string()).optional());

const multipartTouchObservations = z.preprocess((value) => {
  if (value === undefined || value === '') return undefined;
  if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
    return value as Record<string, string>;
  }
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, string>;
      }
    } catch {
      return undefined;
    }
  }
  return undefined;
}, z.record(z.string()).optional());

export const createConsultationSchema = z.object({
  patientId: z.string().uuid(),
  symptoms: z.string().min(5),
  clinicalNotes: z.string().optional(),
  urgency: z.nativeEnum(UrgencyLevel).default(UrgencyLevel.MEDIUM),
  earSide: z.nativeEnum(EarSide).default(EarSide.BOTH),
  showSources: z.coerce.boolean().default(true),
  requestSpecialistReview: z.coerce.boolean().default(false),
  symptomIds: multipartStringArray,
  symptomLabels: multipartStringArray,
  medicalHistoryIds: multipartStringArray,
  medicalHistoryLabels: multipartStringArray,
  touchCheckIds: multipartStringArray,
  touchCheckLabels: multipartStringArray,
  touchObservations: multipartTouchObservations
});

