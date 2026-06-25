import type { AccountStatus, Role } from '@prisma/client';

export type UserRecord = {
  id: string;
  fullName: string;
  email: string;
  passwordHash: string;
  role: Role;
  accountStatus: AccountStatus;
  matricule?: string;
  supervisorMatricule?: string;
  rejectionReason?: string;
  phone?: string;
  healthFacility?: string;
  professionalId?: string;
  linkedPatientId?: string;
  createdAt: string;
};

export type PublicUser = Omit<UserRecord, 'passwordHash'>;
