import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';
import { HttpError, unauthorized } from '../../common/errors/http-error.js';
import type { AuthenticatedUser, Role } from '../../common/types.js';
import { userDao, toPublicUser } from '../users/user.dao.js';
import type { UserRecord } from '../users/user.types.js';
import { patientDao } from '../patients/patient.dao.js';

type JwtPayload = {
  sub: string;
  role: Role;
};

const authPayload = (user: UserRecord) => ({
  user: toPublicUser(user),
  accessToken: signAccessToken(user),
  refreshToken: signRefreshToken(user)
});

export const signAccessToken = (user: UserRecord) =>
  jwt.sign({ sub: user.id, role: user.role }, env.JWT_ACCESS_SECRET, { expiresIn: '30m' });

export const signRefreshToken = (user: UserRecord) =>
  jwt.sign({ sub: user.id, role: user.role }, env.JWT_REFRESH_SECRET, { expiresIn: '30d' });

const toAuthenticatedUser = (user: UserRecord): AuthenticatedUser => ({
  id: user.id,
  fullName: user.fullName,
  email: user.email,
  role: user.role,
  phone: user.phone,
  healthFacility: user.healthFacility,
  professionalId: user.professionalId,
  linkedPatientId: user.linkedPatientId,
  createdAt: user.createdAt
});

export const authService = {
  async resolveAuthenticatedUser(token: string): Promise<AuthenticatedUser> {
    const payload = jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
    let user = await userDao.findById(payload.sub);
    if (!user) throw unauthorized('Session invalide');

    if (user.role === 'PATIENT' && !user.linkedPatientId) {
      user = await this.ensurePatientProfileLinked(user);
    }

    return toAuthenticatedUser(user);
  },

  async ensurePatientProfileLinked(user: UserRecord): Promise<UserRecord> {
    let patient = await patientDao.findByUserId(user.id);
    if (!patient) {
      const names = user.fullName.split(' ');
      const firstName = names[0] || 'Patient';
      const lastName = names.slice(1).join(' ') || 'Korai';
      patient = await patientDao.create({
        userId: user.id,
        createdByUserId: user.id,
        firstName,
        lastName,
        consentForAi: false,
        consentForTeleExpertise: false,
        isValidated: false
      });
    }
    const updated = await userDao.update(user.id, { linkedPatientId: patient.id });
    return updated ?? user;
  },

  async register(input: { fullName: string; email: string; password: string; role: Role }) {
    const existing = await userDao.findByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await userDao.create(input);
    return authPayload(user);
  },

  async registerNurse(input: {
    fullName: string;
    email: string;
    password: string;
    phone?: string;
    healthFacility: string;
    professionalId?: string;
  }) {
    const existing = await userDao.findByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await userDao.create({ ...input, role: 'NURSE' });
    return authPayload(user);
  },

  async registerPatient(input: {
    firstName: string;
    lastName: string;
    email: string;
    password: string;
    birthDate?: string;
    sex?: 'F' | 'M';
    phone?: string;
    address?: string;
    consentForAi: boolean;
    consentForTeleExpertise: boolean;
  }) {
    const existing = await userDao.findByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await userDao.create({
      fullName: `${input.firstName} ${input.lastName}`,
      email: input.email,
      password: input.password,
      role: 'PATIENT',
      phone: input.phone
    });

    const patient = await patientDao.create({
      userId: user.id,
      createdByUserId: user.id,
      firstName: input.firstName,
      lastName: input.lastName,
      birthDate: input.birthDate,
      sex: input.sex,
      phone: input.phone,
      address: input.address,
      consentForAi: input.consentForAi,
      consentForTeleExpertise: input.consentForTeleExpertise,
      isValidated: false
    });

    const linkedUser = (await userDao.update(user.id, { linkedPatientId: patient.id })) ?? user;

    return {
      ...authPayload(linkedUser),
      patient
    };
  },

  async login(input: { email: string; password: string }) {
    const user = await userDao.findByEmail(input.email);
    if (!user) throw unauthorized('Email ou mot de passe incorrect');

    const passwordOk = await bcrypt.compare(input.password, user.passwordHash);
    if (!passwordOk) throw unauthorized('Email ou mot de passe incorrect');

    return authPayload(user);
  },

  async updateProfile(
    userId: string,
    data: {
      fullName?: string;
      phone?: string;
      healthFacility?: string;
      professionalId?: string;
    }
  ) {
    const user = await userDao.findById(userId);
    if (!user) throw new HttpError(404, 'USER_NOT_FOUND', 'Utilisateur introuvable');

    const updated = await userDao.update(userId, {
      fullName: data.fullName ?? user.fullName,
      phone: data.phone ?? user.phone,
      healthFacility: data.healthFacility ?? user.healthFacility,
      professionalId: data.professionalId ?? user.professionalId
    });

    return toAuthenticatedUser(updated!);
  },

  async updatePassword(userId: string, currentPassword: string, newPassword: string) {
    const user = await userDao.findById(userId);
    if (!user) throw new HttpError(404, 'USER_NOT_FOUND', 'Utilisateur introuvable');

    const passwordOk = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!passwordOk) throw new HttpError(400, 'INVALID_PASSWORD', 'Le mot de passe actuel est incorrect');

    const newHash = await bcrypt.hash(newPassword, 10);
    await userDao.updatePassword(userId, newHash);
  }
};
