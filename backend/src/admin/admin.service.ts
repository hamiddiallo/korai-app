import bcrypt from 'bcryptjs';
import { HttpError, forbidden, notFound } from '../common/http-error.js';
import { prisma } from '../common/prisma.js';
import type { Patient, Role, User } from '../types.js';

const nullable = <T>(value: T | null): T | undefined => value ?? undefined;

const publicUser = (user: {
  id: string;
  fullName: string;
  email: string;
  role: string;
  phone: string | null;
  healthFacility: string | null;
  professionalId: string | null;
  linkedPatientId: string | null;
  createdAt: Date;
}) => ({
  id: user.id,
  fullName: user.fullName,
  email: user.email,
  role: user.role as Role,
  phone: nullable(user.phone),
  healthFacility: nullable(user.healthFacility),
  professionalId: nullable(user.professionalId),
  linkedPatientId: nullable(user.linkedPatientId),
  createdAt: user.createdAt.toISOString()
});

const mapPatient = (patient: {
  id: string;
  userId: string | null;
  createdByUserId: string;
  firstName: string;
  lastName: string;
  birthDate: string | null;
  sex: string | null;
  phone: string | null;
  address: string | null;
  consentForAi: boolean;
  consentForTeleExpertise: boolean;
  isValidated: boolean;
  createdAt: Date;
  updatedAt: Date;
}): Patient => ({
  id: patient.id,
  userId: nullable(patient.userId),
  createdByUserId: patient.createdByUserId,
  firstName: patient.firstName,
  lastName: patient.lastName,
  birthDate: nullable(patient.birthDate),
  sex: patient.sex ? (patient.sex as Patient['sex']) : undefined,
  phone: nullable(patient.phone),
  address: nullable(patient.address),
  consentForAi: patient.consentForAi,
  consentForTeleExpertise: patient.consentForTeleExpertise,
  isValidated: patient.isValidated,
  createdAt: patient.createdAt.toISOString(),
  updatedAt: patient.updatedAt.toISOString()
});

export const adminService = {
  async listUsers() {
    const users = await prisma.user.findMany({ orderBy: { createdAt: 'desc' } });
    return users.map(publicUser);
  },

  async createUser(input: {
    fullName: string;
    email: string;
    password: string;
    role: Role;
    phone?: string;
    healthFacility?: string;
    professionalId?: string;
  }) {
    const existing = await prisma.user.findUnique({ where: { email: input.email.toLowerCase() } });
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await prisma.user.create({
      data: {
        fullName: input.fullName,
        email: input.email.toLowerCase(),
        passwordHash: await bcrypt.hash(input.password, 10),
        role: input.role,
        phone: input.phone,
        healthFacility: input.healthFacility,
        professionalId: input.professionalId
      }
    });
    return publicUser(user);
  },

  async updateUser(id: string, input: Partial<Omit<User, 'id' | 'createdAt' | 'passwordHash'>>) {
    const existing = await prisma.user.findUnique({ where: { id } });
    if (!existing) throw notFound('Utilisateur introuvable');

    if (input.email && input.email.toLowerCase() !== existing.email) {
      const duplicate = await prisma.user.findUnique({ where: { email: input.email.toLowerCase() } });
      if (duplicate) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');
    }

    const user = await prisma.user.update({
      where: { id },
      data: {
        fullName: input.fullName,
        email: input.email?.toLowerCase(),
        role: input.role,
        phone: input.phone,
        healthFacility: input.healthFacility,
        professionalId: input.professionalId
      }
    });
    return publicUser(user);
  },

  async deleteUser(id: string, currentUserId: string) {
    if (id === currentUserId) throw forbidden('Un admin ne peut pas supprimer son propre compte');

    const existing = await prisma.user.findUnique({ where: { id } });
    if (!existing) throw notFound('Utilisateur introuvable');

    if (existing.role === 'ADMIN') {
      const admins = await prisma.user.count({ where: { role: 'ADMIN' } });
      if (admins <= 1) throw forbidden('Impossible de supprimer le dernier compte admin');
    }

    const linkedPatients = await prisma.patient.count({
      where: { OR: [{ userId: id }, { createdByUserId: id }] }
    });
    const linkedCases = await prisma.orlCase.count({
      where: { OR: [{ createdByUserId: id }, { assignedSpecialistId: id }] }
    });
    if (linkedPatients > 0 || linkedCases > 0) {
      throw new HttpError(
        409,
        'USER_HAS_CLINICAL_DATA',
        'Ce compte est lie a des donnees cliniques et ne peut pas etre supprime'
      );
    }

    await prisma.user.delete({ where: { id } });
    return { deleted: true };
  },

  async listPatients() {
    const patients = await prisma.patient.findMany({ orderBy: { updatedAt: 'desc' } });
    return patients.map(mapPatient);
  },

  async updatePatient(id: string, input: Partial<Patient>) {
    const existing = await prisma.patient.findUnique({ where: { id } });
    if (!existing) throw notFound('Patient introuvable');

    const patient = await prisma.patient.update({
      where: { id },
      data: {
        firstName: input.firstName,
        lastName: input.lastName,
        birthDate: input.birthDate,
        sex: input.sex,
        phone: input.phone,
        address: input.address,
        consentForAi: input.consentForAi,
        consentForTeleExpertise: input.consentForTeleExpertise,
        isValidated: input.isValidated
      }
    });
    return mapPatient(patient);
  },

  async deletePatient(id: string) {
    const existing = await prisma.patient.findUnique({ where: { id } });
    if (!existing) throw notFound('Patient introuvable');
    const cases = await prisma.orlCase.count({ where: { patientId: id } });
    if (cases > 0) {
      throw new HttpError(
        409,
        'PATIENT_HAS_CASES',
        'Ce patient possede des consultations et ne peut pas etre supprime'
      );
    }
    await prisma.patient.delete({ where: { id } });
    return { deleted: true };
  },

  async listClinicalItems(type?: string) {
    return prisma.clinicalReferenceItem.findMany({
      where: type ? { type } : undefined,
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { label: 'asc' }]
    });
  },

  async createClinicalItem(input: {
    type: string;
    label: string;
    description?: string;
    isActive: boolean;
    sortOrder: number;
  }) {
    return prisma.clinicalReferenceItem.create({ data: input });
  },

  async updateClinicalItem(
    id: string,
    input: Partial<{ type: string; label: string; description?: string; isActive: boolean; sortOrder: number }>
  ) {
    const existing = await prisma.clinicalReferenceItem.findUnique({ where: { id } });
    if (!existing) throw notFound('Element clinique introuvable');
    return prisma.clinicalReferenceItem.update({ where: { id }, data: input });
  },

  async deleteClinicalItem(id: string) {
    const existing = await prisma.clinicalReferenceItem.findUnique({ where: { id } });
    if (!existing) throw notFound('Element clinique introuvable');
    await prisma.clinicalReferenceItem.delete({ where: { id } });
    return { deleted: true };
  }
};
