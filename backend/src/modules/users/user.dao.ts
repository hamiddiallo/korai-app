import bcrypt from 'bcryptjs';
import type { Role } from '@prisma/client';
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
        phone: input.phone,
        healthFacility: input.healthFacility,
        professionalId: input.professionalId,
        linkedPatientId: input.linkedPatientId
      }
    });
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
