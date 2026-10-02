import type { ClinicalReferenceType } from '@prisma/client';
import { prisma } from '../../common/prisma.js';

export const clinicalReferenceDao = {
  async listActive(type?: ClinicalReferenceType) {
    return prisma.clinicalReferenceItem.findMany({
      where: {
        isActive: true,
        ...(type ? { type } : {})
      },
      orderBy: [{ label: 'asc' }]
    });
  },

  async listAll(type?: ClinicalReferenceType) {
    return prisma.clinicalReferenceItem.findMany({
      where: type ? { type } : undefined,
      orderBy: [{ type: 'asc' }, { label: 'asc' }]
    });
  },

  async findById(id: string) {
    return prisma.clinicalReferenceItem.findUnique({ where: { id } });
  },

  /** Scores de danger (0–3) indexés par id, pour les ids fournis. */
  async dangerScoresByIds(ids: string[]): Promise<Map<string, number>> {
    if (ids.length === 0) return new Map();
    const rows = await prisma.clinicalReferenceItem.findMany({
      where: { id: { in: ids } },
      select: { id: true, dangerScore: true }
    });
    return new Map(rows.map((row) => [row.id, row.dangerScore]));
  },

  async create(data: {
    type: ClinicalReferenceType;
    label: string;
    description?: string;
    isActive: boolean;
    sortOrder: number;
    dangerScore?: number;
  }) {
    return prisma.clinicalReferenceItem.create({ data });
  },

  async update(
    id: string,
    data: Partial<{
      type: ClinicalReferenceType;
      label: string;
      description?: string;
      isActive: boolean;
      sortOrder: number;
      dangerScore: number;
    }>
  ) {
    return prisma.clinicalReferenceItem.update({ where: { id }, data });
  },

  async delete(id: string) {
    await prisma.clinicalReferenceItem.delete({ where: { id } });
  },

  /**
   * Crée l'élément s'il n'existe pas encore. N'écrase jamais un élément
   * existant : les réglages de l'administrateur (score de danger, définition)
   * survivent aux redémarrages.
   */
  async createIfMissing(item: {
    type: ClinicalReferenceType;
    label: string;
    description?: string;
    sortOrder: number;
    dangerScore?: number;
  }) {
    const existing = await prisma.clinicalReferenceItem.findFirst({
      where: { type: item.type, label: item.label }
    });
    return existing ?? prisma.clinicalReferenceItem.create({ data: item });
  }
};
