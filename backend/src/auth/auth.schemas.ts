import { z } from 'zod';

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
});

export const adminRegisterSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  role: z.enum(['NURSE', 'SPECIALIST', 'PATIENT', 'ADMIN'])
});

export const registerNurseSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  phone: z.string().min(5).optional(),
  healthFacility: z.string().min(2),
  professionalId: z.string().min(2).optional()
});

export const registerPatientSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(8),
  birthDate: z.string().optional(),
  sex: z.enum(['F', 'M']).optional(),
  phone: z.string().min(5).optional(),
  address: z.string().optional(),
  consentForAi: z.boolean().default(false),
  consentForTeleExpertise: z.boolean().default(false)
});
