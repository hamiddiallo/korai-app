import type { ClinicalReferenceType, Role } from '@prisma/client';
import { prisma } from '../../common/prisma.js';

export const adminDao = {
  countConsultationsForPatient(patientId: string) {
    return prisma.consultation.count({ where: { patientId } });
  },

  async deleteClinicalItem(id: string) {
    await prisma.clinicalReferenceItem.delete({ where: { id } });
  },

  async findClinicalItem(id: string) {
    return prisma.clinicalReferenceItem.findUnique({ where: { id } });
  },

  async createClinicalItem(data: {
    type: ClinicalReferenceType;
    label: string;
    description?: string;
    isActive: boolean;
    sortOrder: number;
  }) {
    return prisma.clinicalReferenceItem.create({ data });
  },

  async updateClinicalItem(
    id: string,
    data: Partial<{
      type: ClinicalReferenceType;
      label: string;
      description?: string;
      isActive: boolean;
      sortOrder: number;
    }>
  ) {
    return prisma.clinicalReferenceItem.update({ where: { id }, data });
  },

  async countUsersByRole(role: Role) {
    return prisma.user.count({ where: { role } });
  }
};
