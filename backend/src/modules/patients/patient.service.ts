import { Prisma } from '@prisma/client';
import { patientScope } from '../../common/access/access-policy.js';
import type { AuthenticatedUser } from '../../common/types.js';
import { patientDao } from './patient.dao.js';
import type { PatientRecord } from './patient.types.js';

type CreatePatientInput = Omit<
  PatientRecord,
  'id' | 'createdAt' | 'updatedAt' | 'createdByUserId' | 'userId' | 'facilityId' | 'isValidated'
> & { userId?: string; isValidated?: boolean };

export const patientService = {
  /** Dossier créé par un soignant : rattaché à son établissement. */
  create(user: AuthenticatedUser, input: CreatePatientInput) {
    return this.createIdempotent(user.id, { ...input, facilityId: user.facilityId });
  },

  async createIdempotent(createdByUserId: string, input: CreatePatientInput & { facilityId?: string }) {
    if (input.clientMutationId) {
      const existing = await patientDao.findByClientMutationId(createdByUserId, input.clientMutationId);
      if (existing) return existing;
    }
    if (input.clientLocalId) {
      const existing = await patientDao.findByClientLocalId(createdByUserId, input.clientLocalId);
      if (existing) return existing;
    }

    try {
      return await patientDao.create({
        ...input,
        createdByUserId,
        isValidated: input.isValidated ?? true
      });
    } catch (error) {
      // Même fiche envoyée deux fois en même temps : la seconde renvoie la première.
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const again =
          (input.clientMutationId && (await patientDao.findByClientMutationId(createdByUserId, input.clientMutationId))) ||
          (input.clientLocalId && (await patientDao.findByClientLocalId(createdByUserId, input.clientLocalId)));
        if (again) return again;
      }
      throw error;
    }
  },

  listForUser(user: AuthenticatedUser) {
    return patientDao.list(patientScope(user));
  },

  findById(id: string) {
    return patientDao.findById(id);
  },

  update(id: string, patch: Partial<PatientRecord>, system: { facilityId?: string } = {}) {
    return patientDao.update(id, patch, system);
  }
};
