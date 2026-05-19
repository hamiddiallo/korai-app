import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { HttpError, unauthorized } from '../common/http-error.js';
import { store } from '../common/data-store.js';
import type { Role, User } from '../types.js';

const publicUser = (user: User) => ({
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

const authPayload = (user: User) => ({
  user: publicUser(user),
  accessToken: signAccessToken(user),
  refreshToken: signRefreshToken(user)
});

export const signAccessToken = (user: User) =>
  jwt.sign({ sub: user.id, role: user.role }, env.JWT_ACCESS_SECRET, { expiresIn: '30m' });

export const signRefreshToken = (user: User) =>
  jwt.sign({ sub: user.id, role: user.role }, env.JWT_REFRESH_SECRET, { expiresIn: '30d' });

export const authService = {
  async register(input: { fullName: string; email: string; password: string; role: Role }) {
    const existing = await store.findUserByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await store.createUser(input);
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
    const existing = await store.findUserByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await store.createUser({
      ...input,
      role: 'NURSE'
    });
    return authPayload(user);
  },

  async registerPatient(input: {
    firstName: string;
    lastName: string;
    email: string;
    password: string;
    birthDate?: string;
    sex?: 'F' | 'M' | 'OTHER';
    phone?: string;
    address?: string;
    consentForAi: boolean;
    consentForTeleExpertise: boolean;
  }) {
    const existing = await store.findUserByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await store.createUser({
      fullName: `${input.firstName} ${input.lastName}`,
      email: input.email,
      password: input.password,
      role: 'PATIENT',
      phone: input.phone
    });

    const patient = await store.createPatient({
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
    const linkedUser = (await store.updateUser(user.id, { linkedPatientId: patient.id })) ?? user;

    return {
      ...authPayload(linkedUser),
      patient
    };
  },

  async login(input: { email: string; password: string }) {
    const user = await store.findUserByEmail(input.email);
    if (!user) throw unauthorized('Email ou mot de passe incorrect');

    const passwordOk = await bcrypt.compare(input.password, user.passwordHash);
    if (!passwordOk) throw unauthorized('Email ou mot de passe incorrect');

    return authPayload(user);
  }
};
