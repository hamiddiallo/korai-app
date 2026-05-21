import type { Role } from '../../common/types.js';

export type UserRecord = {
  id: string;
  fullName: string;
  email: string;
  passwordHash: string;
  role: Role;
  phone?: string;
  healthFacility?: string;
  professionalId?: string;
  linkedPatientId?: string;
  createdAt: string;
};

export type PublicUser = Omit<UserRecord, 'passwordHash'>;
