import type { Sex } from '@prisma/client';

export type PatientRecord = {
  id: string;
  userId?: string;
  createdByUserId: string;
  firstName: string;
  lastName: string;
  birthDate?: string;
  sex?: Sex;
  phone?: string;
  address?: string;
  consentForAi: boolean;
  consentForTeleExpertise: boolean;
  consentForAiAt?: string;
  consentForTeleExpertiseAt?: string;
  /** Établissement qui suit le patient (absent : pas encore rattaché). */
  facilityId?: string;
  isValidated: boolean;
  clientLocalId?: string;
  clientMutationId?: string;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string;
};
