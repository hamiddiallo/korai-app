import type { Sex } from '@prisma/client';
import { prisma } from '../../common/prisma.js';
import type { PatientRecord } from './patient.types.js';

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const mapPatient = (patient: {
  id: string;
  userId: string | null;
  createdByUserId: string;
  firstName: string;
  lastName: string;
  birthDate: string | null;
  sex: Sex | null;
  phone: string | null;
  address: string | null;
  consentForAi: boolean;
  consentForTeleExpertise: boolean;
  isValidated: boolean;
  clientLocalId: string | null;
  clientMutationId: string | null;
  createdAt: Date;
  updatedAt: Date;
}): PatientRecord => ({
  id: patient.id,
  userId: nullable(patient.userId),
  createdByUserId: patient.createdByUserId,
  firstName: patient.firstName,
  lastName: patient.lastName,
  birthDate: nullable(patient.birthDate),
  sex: patient.sex ?? undefined,
  phone: nullable(patient.phone),
  address: nullable(patient.address),
  consentForAi: patient.consentForAi,
  consentForTeleExpertise: patient.consentForTeleExpertise,
  isValidated: patient.isValidated,
  clientLocalId: nullable(patient.clientLocalId),
  clientMutationId: nullable(patient.clientMutationId),
  createdAt: patient.createdAt.toISOString(),
  updatedAt: patient.updatedAt.toISOString()
});

export const patientDao = {
  async create(input: {
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
  }) {
    const patient = await prisma.patient.create({ data: input });
    return mapPatient(patient);
  },

  async findByClientLocalId(createdByUserId: string, clientLocalId: string) {
    const patient = await prisma.patient.findUnique({
      where: {
        createdByUserId_clientLocalId: {
          createdByUserId,
          clientLocalId
        }
      }
    });
    return patient ? mapPatient(patient) : undefined;
  },

  async findByClientMutationId(createdByUserId: string, clientMutationId: string) {
    const patient = await prisma.patient.findUnique({
      where: {
        createdByUserId_clientMutationId: {
          createdByUserId,
          clientMutationId
        }
      }
    });
    return patient ? mapPatient(patient) : undefined;
  },

  async findById(id: string) {
    const patient = await prisma.patient.findUnique({ where: { id } });
    return patient ? mapPatient(patient) : undefined;
  },

  async findByUserId(userId: string) {
    const patient = await prisma.patient.findUnique({ where: { userId } });
    return patient ? mapPatient(patient) : undefined;
  },

  async list(createdByUserId?: string) {
    const patients = await prisma.patient.findMany({
      where: createdByUserId ? { createdByUserId } : undefined,
      orderBy: { updatedAt: 'desc' }
    });
    return patients.map(mapPatient);
  },

  async update(
    id: string,
    patch: Partial<{
      firstName: string;
      lastName: string;
      birthDate?: string;
      sex?: Sex;
      phone?: string;
      address?: string;
      consentForAi: boolean;
      consentForTeleExpertise: boolean;
      isValidated: boolean;
    }>
  ) {
    const patient = await prisma.patient.update({
      where: { id },
      data: patch
    });
    return mapPatient(patient);
  },

  async delete(id: string) {
    await prisma.patient.delete({ where: { id } });
  },

  async countConsultations(patientId: string) {
    return prisma.consultation.count({ where: { patientId } });
  }
};
