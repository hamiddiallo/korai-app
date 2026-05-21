import { ClinicalReferenceType } from '@prisma/client';
import { z } from 'zod';

export const clinicalItemTypeSchema = z.nativeEnum(ClinicalReferenceType);

export const createAdminUserSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  role: z.enum(['NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN']),
  phone: z.string().optional(),
  healthFacility: z.string().optional(),
  professionalId: z.string().optional()
});

export const updateAdminUserSchema = createAdminUserSchema.partial().omit({ password: true });

export const updateAdminPatientSchema = z.object({
  firstName: z.string().min(1).optional(),
  lastName: z.string().min(1).optional(),
  birthDate: z.string().optional(),
  sex: z.enum(['F', 'M']).optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  consentForAi: z.boolean().optional(),
  consentForTeleExpertise: z.boolean().optional(),
  isValidated: z.boolean().optional()
});

export const createClinicalItemSchema = z.object({
  type: clinicalItemTypeSchema,
  label: z.string().min(1),
  description: z.string().optional(),
  isActive: z.boolean().default(true),
  sortOrder: z.number().int().default(0)
});

export const updateClinicalItemSchema = createClinicalItemSchema.partial();
