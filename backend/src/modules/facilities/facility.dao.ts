import { prisma } from '../../common/prisma.js';

export type FacilityRecord = { id: string; name: string };

/**
 * Nom comparable d'un établissement : minuscules, sans accents, espaces
 * réduits. « Hôpital  Fann » et « hopital fann » désignent le même lieu.
 * ⚠️ Identique à la normalisation SQL de la migration
 * `20260928090000_facilities_consent_audit`.
 */
export const normalizeFacilityName = (name: string) =>
  name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');

/** Nom affiché : espaces superflus retirés, casse d'origine conservée. */
const displayName = (name: string) => name.trim().replace(/\s+/g, ' ');

export const facilityDao = {
  async list(): Promise<FacilityRecord[]> {
    return prisma.facility.findMany({ select: { id: true, name: true }, orderBy: { name: 'asc' } });
  },

  /** Vue admin : nombre de soignants et de patients rattachés. */
  async listWithCounts() {
    const rows = await prisma.facility.findMany({
      orderBy: { name: 'asc' },
      select: {
        id: true,
        name: true,
        _count: {
          select: {
            users: { where: { deletedAt: null, role: 'NURSE' } },
            patients: { where: { deletedAt: null } }
          }
        }
      }
    });
    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      nurseCount: row._count.users,
      patientCount: row._count.patients
    }));
  },

  async findById(id: string): Promise<FacilityRecord | undefined> {
    const row = await prisma.facility.findUnique({ where: { id }, select: { id: true, name: true } });
    return row ?? undefined;
  },

  /** Établissement existant portant ce nom (aux accents et à la casse près), sinon créé. */
  async findOrCreate(name: string): Promise<FacilityRecord> {
    const normalizedName = normalizeFacilityName(name);
    return prisma.facility.upsert({
      where: { normalizedName },
      update: {},
      create: { name: displayName(name), normalizedName },
      select: { id: true, name: true }
    });
  }
};
