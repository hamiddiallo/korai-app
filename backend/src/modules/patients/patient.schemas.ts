import { z } from 'zod';

export const createPatientSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  birthDate: z.string().optional(),
  sex: z.enum(['F', 'M']).optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  consentForAi: z.boolean().default(false),
  consentForTeleExpertise: z.boolean().default(false),
  clientLocalId: z.string().min(1).optional(),
  clientMutationId: z.string().min(1).optional()
});

/**
 * Champs modifiables d'une fiche patient. Liste fermée (`strict`) : toute autre
 * clé (relations Prisma comme `creator`, `account`, `consultations`, ou champs
 * techniques) est refusée — elle permettait d'écrire dans d'autres tables.
 */
export const updatePatientSchema = z
  .object({
    firstName: z.string().trim().min(1).max(100).optional(),
    lastName: z.string().trim().min(1).max(100).optional(),
    birthDate: z.string().max(40).nullable().optional(),
    sex: z.enum(['F', 'M']).optional(),
    phone: z.string().max(30).optional(),
    address: z.string().max(200).optional(),
    consentForAi: z.boolean().optional(),
    consentForTeleExpertise: z.boolean().optional(),
    isValidated: z.boolean().optional()
  })
  .strict();
