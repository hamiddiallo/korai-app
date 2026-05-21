import { z } from 'zod';

export const createPatientSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  birthDate: z.string().optional(),
  sex: z.enum(['F', 'M']).optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  consentForAi: z.boolean().default(false),
  consentForTeleExpertise: z.boolean().default(false)
});
