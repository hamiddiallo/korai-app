import type { ClinicalReferenceType } from '@prisma/client';
import { clinicalReferenceDao } from './clinical-reference.dao.js';

export const clinicalReferenceService = {
  listForClinicalWorkflow(type?: ClinicalReferenceType) {
    return clinicalReferenceDao.listActive(type);
  },

  listForAdmin(type?: ClinicalReferenceType) {
    return clinicalReferenceDao.listAll(type);
  }
};
