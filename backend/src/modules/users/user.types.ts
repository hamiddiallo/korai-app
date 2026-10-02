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
  /** Établissement du soignant (périmètre des dossiers qu'il peut consulter). */
  facilityId?: string;
  professionalId?: string;
  linkedPatientId?: string;
  createdAt: string;
};

export type PublicUser = Omit<UserRecord, 'passwordHash'>;
