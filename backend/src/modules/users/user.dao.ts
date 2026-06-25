import bcrypt from 'bcryptjs';
import type { AccountStatus, Prisma, Role } from '@prisma/client';
import { prisma } from '../../common/prisma.js';
import { normalizeRole } from '../../common/types.js';
import type { PublicUser, UserRecord } from './user.types.js';

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const mapUser = (user: {
  id: string;
  fullName: string;
  email: string;
  passwordHash: string;
  role: Role;
  accountStatus: AccountStatus;
  matricule: string | null;
  supervisorMatricule: string | null;
  rejectionReason: string | null;
  phone: string | null;
  healthFacility: string | null;
  professionalId: string | null;
  linkedPatientId: string | null;
  createdAt: Date;
}): UserRecord => ({
  id: user.id,
  fullName: user.fullName,
  email: user.email,
  passwordHash: user.passwordHash,
  role: normalizeRole(String(user.role)),
  accountStatus: user.accountStatus,
  matricule: nullable(user.matricule),
  supervisorMatricule: nullable(user.supervisorMatricule),
  rejectionReason: nullable(user.rejectionReason),
  phone: nullable(user.phone),
  healthFacility: nullable(user.healthFacility),
  professionalId: nullable(user.professionalId),
  linkedPatientId: nullable(user.linkedPatientId),
  createdAt: user.createdAt.toISOString()
});

export const toPublicUser = (user: UserRecord): PublicUser => {
  const { passwordHash: _passwordHash, ...publicUser } = user;
  return publicUser;
};

export const userDao = {
  async count() {
    return prisma.user.count();
  },

  async findByEmail(email: string) {
    const user = await prisma.user.findFirst({
      where: { email: email.toLowerCase(), deletedAt: null }
    });
    return user ? mapUser(user) : undefined;
  },

  async findById(id: string) {
    const user = await prisma.user.findFirst({ where: { id, deletedAt: null } });
    return user ? mapUser(user) : undefined;
  },

  async list() {
    const users = await prisma.user.findMany({
      where: { deletedAt: null },
      orderBy: { createdAt: 'desc' }
    });
    return users.map(mapUser);
  },

  async create(input: {
    fullName: string;
    email: string;
    password: string;
    role: Role;
    accountStatus?: AccountStatus;
    matricule?: string;
    supervisorMatricule?: string;
    phone?: string;
    healthFacility?: string;
    professionalId?: string;
    linkedPatientId?: string;
  }) {
    const existing = await this.findByEmail(input.email);
    if (existing) return existing;

    const user = await prisma.user.create({
      data: {
        fullName: input.fullName,
        email: input.email.toLowerCase(),
        passwordHash: await bcrypt.hash(input.password, 10),
        role: input.role,
        accountStatus: input.accountStatus,
        matricule: input.matricule,
        supervisorMatricule: input.supervisorMatricule,
        phone: input.phone,
        healthFacility: input.healthFacility,
        professionalId: input.professionalId,
        linkedPatientId: input.linkedPatientId
      }
    });
    return mapUser(user);
  },

  /** Compte SPECIALIST (non supprimé) lié à un matricule du registre. */
  async findSpecialistByMatricule(matricule: string) {
    const user = await prisma.user.findFirst({
      where: { matricule, role: 'SPECIALIST', deletedAt: null }
    });
    return user ? mapUser(user) : undefined;
  },

  /** Infirmiers rattachés à un matricule encadrant (filtre statut optionnel). */
  async listNursesBySupervisorMatricule(
    supervisorMatricule: string,
    accountStatus?: AccountStatus
  ) {
    const users = await prisma.user.findMany({
      where: {
        role: 'NURSE',
        supervisorMatricule,
        deletedAt: null,
        ...(accountStatus ? { accountStatus } : {})
      },
      orderBy: { createdAt: 'desc' }
    });
    return users.map(mapUser);
  },

  /** Tous les infirmiers d'un statut donné (vue admin). */
  async listNursesByStatus(accountStatus: AccountStatus) {
    const users = await prisma.user.findMany({
      where: { role: 'NURSE', accountStatus, deletedAt: null },
      orderBy: { createdAt: 'desc' }
    });
    return users.map(mapUser);
  },

  async setAccountStatus(
    id: string,
    accountStatus: AccountStatus,
    rejectionReason?: string | null
  ) {
    const data: Prisma.UserUpdateInput = { accountStatus };
    if (rejectionReason !== undefined) data.rejectionReason = rejectionReason;
    const user = await prisma.user.update({ where: { id }, data });
    return mapUser(user);
  },

  async update(
    id: string,
    patch: Partial<{
      fullName: string;
      email: string;
      role: Role;
      phone?: string;
      healthFacility?: string;
      professionalId?: string;
      linkedPatientId?: string;
    }>
  ) {
    const user = await prisma.user.update({
      where: { id },
      data: {
        fullName: patch.fullName,
        email: patch.email?.toLowerCase(),
        role: patch.role,
        phone: patch.phone,
        healthFacility: patch.healthFacility,
        professionalId: patch.professionalId,
        linkedPatientId: patch.linkedPatientId
      }
    });
    return mapUser(user);
  },

  async updatePassword(id: string, passwordHash: string) {
    await prisma.user.update({
      where: { id },
      data: { passwordHash }
    });
  },

  async delete(id: string) {
    await prisma.user.update({ where: { id }, data: { deletedAt: new Date() } });
  },

  async restore(id: string) {
    const user = await prisma.user.update({
      where: { id },
      data: { deletedAt: null }
    });
    return mapUser(user);
  },

  async countByRole(role: Role) {
    return prisma.user.count({ where: { role, deletedAt: null } });
  },

  async listIdsByRole(role: Role) {
    const rows = await prisma.user.findMany({
      where: { role, deletedAt: null },
      select: { id: true }
    });
    return rows.map((row) => row.id);
  },

  async countLinkedClinicalData(userId: string) {
    const [linkedPatients, linkedConsultations] = await Promise.all([
      prisma.patient.count({
        where: { deletedAt: null, OR: [{ userId }, { createdByUserId: userId }] }
      }),
      prisma.consultation.count({
        where: { deletedAt: null, OR: [{ createdByUserId: userId }, { assignedSpecialistId: userId }] }
      })
    ]);
    return { linkedPatients, linkedConsultations };
  }
};
