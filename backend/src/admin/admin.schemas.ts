import { z } from 'zod';

export const clinicalItemTypeSchema = z.enum(['SYMPTOM', 'MEDICAL_HISTORY', 'TOUCH_CHECK']);

export const createClinicalItemSchema = z.object({
  type: clinicalItemTypeSchema,
  label: z.string().min(2),
  description: z.string().optional(),
  isActive: z.boolean().default(true),
  sortOrder: z.number().int().default(0)
});

export const updateClinicalItemSchema = createClinicalItemSchema.partial();

export const createAdminUserSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  role: z.enum(['NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN']),
  phone: z.string().optional(),
  healthFacility: z.string().optional(),
  professionalId: z.string().optional()
});

export const updateAdminUserSchema = z.object({
  fullName: z.string().min(2).optional(),
  email: z.string().email().optional(),
  role: z.enum(['NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN']).optional(),
  phone: z.string().optional(),
  healthFacility: z.string().optional(),
  professionalId: z.string().optional()
});

export const updateAdminPatientSchema = z.object({
  firstName: z.string().min(1).optional(),
  lastName: z.string().min(1).optional(),
  birthDate: z.string().optional(),
  sex: z.enum(['F', 'M', 'OTHER']).optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  consentForAi: z.boolean().optional(),
  consentForTeleExpertise: z.boolean().optional()
});
