import type { Prisma, Sex } from '@prisma/client';
import { prisma } from '../../common/prisma.js';
import type { PatientRecord } from './patient.types.js';

/** Seuls champs d'une fiche patient modifiables par une mise à jour. */
export const PATIENT_UPDATABLE_FIELDS = [
  'firstName',
  'lastName',
  'birthDate',
  'sex',
  'phone',
  'address',
  'consentForAi',
  'consentForTeleExpertise',
  'isValidated'
] as const;

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
  consentForAiAt: Date | null;
  consentForTeleExpertiseAt: Date | null;
  facilityId: string | null;
  isValidated: boolean;
  clientLocalId: string | null;
  clientMutationId: string | null;
  createdAt: Date;
  updatedAt: Date;
  deletedAt?: Date | null;
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
  consentForAiAt: patient.consentForAiAt?.toISOString(),
  consentForTeleExpertiseAt: patient.consentForTeleExpertiseAt?.toISOString(),
  facilityId: nullable(patient.facilityId),
  isValidated: patient.isValidated,
  clientLocalId: nullable(patient.clientLocalId),
  clientMutationId: nullable(patient.clientMutationId),
  createdAt: patient.createdAt.toISOString(),
  updatedAt: patient.updatedAt.toISOString(),
  deletedAt: patient.deletedAt?.toISOString()
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
    facilityId?: string;
    isValidated: boolean;
    clientLocalId?: string;
    clientMutationId?: string;
  }) {
    const now = new Date();
    const patient = await prisma.patient.create({
      data: {
        ...input,
        consentForAiAt: input.consentForAi ? now : null,
        consentForTeleExpertiseAt: input.consentForTeleExpertise ? now : null
      }
    });
    return mapPatient(patient);
  },

  async findByClientLocalId(createdByUserId: string, clientLocalId: string) {
    const patient = await prisma.patient.findFirst({
      where: {
        deletedAt: null,
        createdByUserId,
        clientLocalId
      }
    });
    return patient ? mapPatient(patient) : undefined;
  },

  async findByClientMutationId(createdByUserId: string, clientMutationId: string) {
    const patient = await prisma.patient.findFirst({
      where: {
        deletedAt: null,
        createdByUserId,
        clientMutationId
      }
    });
    return patient ? mapPatient(patient) : undefined;
  },

  async findById(id: string) {
    const patient = await prisma.patient.findFirst({ where: { id, deletedAt: null } });
    return patient ? mapPatient(patient) : undefined;
  },

  async findByUserId(userId: string) {
    const patient = await prisma.patient.findFirst({ where: { userId, deletedAt: null } });
    return patient ? mapPatient(patient) : undefined;
  },

  /** Patients non supprimés visibles selon `scope` (voir `patientScope`). */
  async list(scope: Prisma.PatientWhereInput = {}) {
    const patients = await prisma.patient.findMany({
      where: { AND: [{ deletedAt: null }, scope] },
      orderBy: { updatedAt: 'desc' }
    });
    return patients.map(mapPatient);
  },

  async update(
    id: string,
    patch: Partial<{
      firstName: string;
      lastName: string;
      birthDate?: string | null;
      sex?: Sex;
      phone?: string;
      address?: string;
      consentForAi: boolean;
      consentForTeleExpertise: boolean;
      isValidated: boolean;
    }>,
    /** Champs fixés par le serveur, jamais par la requête. */
    system: { facilityId?: string } = {}
  ) {
    // Copie champ par champ : jamais d'objet reçu transmis tel quel à Prisma
    // (les relations imbriquées permettraient d'écrire dans d'autres tables).
    const data: Record<string, unknown> = {};
    for (const key of PATIENT_UPDATABLE_FIELDS) {
      if (patch[key] !== undefined) data[key] = patch[key];
    }
    // Date de l'accord : posée quand il est donné, effacée quand il est retiré.
    const current = await prisma.patient.findUnique({
      where: { id },
      select: { consentForAi: true, consentForTeleExpertise: true }
    });
    const now = new Date();
    if (patch.consentForAi !== undefined && patch.consentForAi !== current?.consentForAi) {
      data.consentForAiAt = patch.consentForAi ? now : null;
    }
    if (
      patch.consentForTeleExpertise !== undefined &&
      patch.consentForTeleExpertise !== current?.consentForTeleExpertise
    ) {
      data.consentForTeleExpertiseAt = patch.consentForTeleExpertise ? now : null;
    }
    if (system.facilityId) data.facilityId = system.facilityId;
    const patient = await prisma.patient.update({ where: { id }, data });
    return mapPatient(patient);
  },

  async delete(id: string) {
    await prisma.patient.update({ where: { id }, data: { deletedAt: new Date() } });
  },

  async restore(id: string) {
    const patient = await prisma.patient.update({
      where: { id },
      data: { deletedAt: null }
    });
    return mapPatient(patient);
  },

  async countConsultations(patientId: string) {
    return prisma.consultation.count({ where: { patientId, deletedAt: null } });
  },

  async listDeleted() {
    const patients = await prisma.patient.findMany({
      where: { deletedAt: { not: null } },
      orderBy: { deletedAt: 'desc' }
    });
    return patients.map(mapPatient);
  },

  async findByIdIncludingDeleted(id: string) {
    const patient = await prisma.patient.findFirst({ where: { id } });
    return patient ? mapPatient(patient) : undefined;
  }
};
