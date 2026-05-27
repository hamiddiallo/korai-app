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
  isValidated: boolean;
  clientLocalId?: string;
  clientMutationId?: string;
  createdAt: string;
  updatedAt: string;
};
