import { store } from '../common/data-store.js';
import { prisma } from '../common/prisma.js';
import type { Patient } from '../types.js';

export const patientService = {
  create(createdByUserId: string, input: Omit<Patient, 'id' | 'createdAt' | 'updatedAt' | 'createdByUserId'>) {
    return store.createPatient({
      ...input,
      createdByUserId
    });
  },

  listForUser(user: { id: string; role: string }) {
    if (user.role === 'ADMIN' || user.role === 'SPECIALIST' || user.role === 'NURSE') {
      return store.listPatients();
    }
    return store.listPatients(user.id);
  },

  findById(id: string) {
    return store.findPatientById(id);
  },

  async update(id: string, patch: Partial<Patient>) {
    const updated = await prisma.patient.update({
      where: { id },
      data: {
        firstName: patch.firstName,
        lastName: patch.lastName,
        birthDate: patch.birthDate,
        sex: patch.sex,
        phone: patch.phone,
        address: patch.address,
        consentForAi: patch.consentForAi,
        consentForTeleExpertise: patch.consentForTeleExpertise,
        isValidated: patch.isValidated
      }
    });
    // Return with mapped structure
    const existing = await store.findPatientById(id);
    return existing;
  }
};
