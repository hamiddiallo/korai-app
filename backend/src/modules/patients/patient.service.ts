import type { AuthenticatedUser } from '../../common/types.js';
import { patientDao } from './patient.dao.js';
import type { PatientRecord } from './patient.types.js';

export const patientService = {
  create(createdByUserId: string, input: Omit<PatientRecord, 'id' | 'createdAt' | 'updatedAt' | 'createdByUserId' | 'userId'> & { userId?: string }) {
    return patientDao.create({
      ...input,
      createdByUserId,
      isValidated: input.isValidated ?? true
    });
  },

  listForUser(user: AuthenticatedUser) {
    if (user.role === 'ADMIN' || user.role === 'SPECIALIST' || user.role === 'NURSE') {
      return patientDao.list();
    }
    return patientDao.list(user.id);
  },

  findById(id: string) {
    return patientDao.findById(id);
  },

  update(id: string, patch: Partial<PatientRecord>) {
    return patientDao.update(id, patch);
  }
};
