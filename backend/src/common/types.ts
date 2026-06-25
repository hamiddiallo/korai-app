import type { Role as PrismaRole } from '@prisma/client';

export type Role = PrismaRole;

/** Ancien libelle encore present en base avant migration enum. */
export const normalizeRole = (role: string): Role => {
  const upper = role.trim().toUpperCase();
  if (upper === 'PROFESSIONAL') return 'NURSE';
  if (upper === 'NURSE' || upper === 'SPECIALIST' || upper === 'PATIENT' || upper === 'ADMIN') {
    return upper as Role;
  }
  return upper as Role;
};

export type AuthenticatedUser = {
  id: string;
  fullName: string;
  email: string;
  role: Role;
  accountStatus: import('@prisma/client').AccountStatus;
  matricule?: string;
  supervisorMatricule?: string;
  phone?: string;
  healthFacility?: string;
  professionalId?: string;
  linkedPatientId?: string;
  createdAt: string;
};

export type AiSummary = {
  imageOpinion?: string;
  ragOpinion?: string;
  likelyDiagnosis?: string;
  confidenceLabel: 'LOW' | 'MEDIUM' | 'HIGH' | 'UNKNOWN';
  warnings: string[];
  sources: string[];
  raw: unknown;
};

import type { EffectiveSummary, ExpertiseReviewApi } from '../modules/expertise/expertise.types.js';

/** Format API legacy `/cases` pour compatibilite frontend. */
export type LegacyOrlCase = {
  id: string;
  externalAiCaseId?: string;
  patientId: string;
  createdByUserId: string;
  assignedSpecialistId?: string;
  earSide: string;
  symptoms: string;
  clinicalNotes?: string;
  symptomIds: string[];
  symptomLabels: string[];
  medicalHistoryIds: string[];
  medicalHistoryLabels: string[];
  touchCheckIds: string[];
  touchCheckLabels: string[];
  touchObservations?: Record<string, string>;
  aiResponse?: unknown;
  organizedAiSummary?: AiSummary;
  expertiseReview?: ExpertiseReviewApi;
  effectiveSummary?: EffectiveSummary;
  status: string;
  urgency: string;
  aiErrorCode?: string;
  aiErrorMessage?: string;
  createdAt: string;
  updatedAt: string;
};
