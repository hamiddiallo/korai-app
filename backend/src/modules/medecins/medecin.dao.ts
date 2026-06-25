import { prisma } from '../../common/prisma.js';

export const medecinDao = {
  findByMatricule(matricule: string) {
    return prisma.medecin.findFirst({
      where: { matricule: matricule.trim(), deletedAt: null }
    });
  },

  findById(id: string) {
    return prisma.medecin.findFirst({ where: { id, deletedAt: null } });
  },

  list() {
    return prisma.medecin.findMany({
      where: { deletedAt: null },
      orderBy: [{ nom: 'asc' }, { prenom: 'asc' }]
    });
  },

  create(input: { matricule: string; nom: string; prenom: string }) {
    return prisma.medecin.create({
      data: {
        matricule: input.matricule.trim(),
        nom: input.nom.trim(),
        prenom: input.prenom.trim()
      }
    });
  },

  update(
    id: string,
    input: Partial<{ matricule: string; nom: string; prenom: string }>
  ) {
    return prisma.medecin.update({
      where: { id },
      data: {
        matricule: input.matricule?.trim(),
        nom: input.nom?.trim(),
        prenom: input.prenom?.trim()
      }
    });
  },

  async softDelete(id: string) {
    await prisma.medecin.update({
      where: { id },
      data: { deletedAt: new Date() }
    });
  }
};
