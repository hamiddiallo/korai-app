import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';
import { HttpError, unauthorized } from '../../common/errors/http-error.js';
import type { AuthenticatedUser, Role } from '../../common/types.js';
import { userDao, toPublicUser } from '../users/user.dao.js';
import type { UserRecord } from '../users/user.types.js';
import { patientDao } from '../patients/patient.dao.js';
import { medecinDao } from '../medecins/medecin.dao.js';
import { notificationService } from '../notifications/notification.service.js';

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
  accountStatus: user.accountStatus,
  matricule: user.matricule,
  supervisorMatricule: user.supervisorMatricule,
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

  /**
   * Inscription d'un spécialiste : son matricule doit exister dans le registre
   * Medecin et ne pas être déjà rattaché à un compte. Le compte est actif
   * immédiatement (vérification par le registre).
   */
  async registerSpecialist(input: {
    fullName: string;
    email: string;
    password: string;
    matricule: string;
    phone?: string;
    healthFacility?: string;
  }) {
    const matricule = input.matricule.trim();
    const medecin = await medecinDao.findByMatricule(matricule);
    if (!medecin) {
      throw new HttpError(
        422,
        'MATRICULE_NOT_FOUND',
        'Matricule introuvable dans le registre des médecins.'
      );
    }

    const claimed = await userDao.findSpecialistByMatricule(matricule);
    if (claimed) {
      throw new HttpError(
        409,
        'MATRICULE_ALREADY_USED',
        'Ce matricule est déjà associé à un compte spécialiste.'
      );
    }

    const existingEmail = await userDao.findByEmail(input.email);
    if (existingEmail) {
      throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');
    }

    const user = await userDao.create({
      fullName: input.fullName,
      email: input.email,
      password: input.password,
      role: 'SPECIALIST',
      accountStatus: 'ACTIVE',
      matricule,
      phone: input.phone,
      healthFacility: input.healthFacility
    });
    return authPayload(user);
  },

  /**
   * Inscription d'un infirmier : le matricule de l'encadrant doit exister dans
   * le registre Medecin. Le compte est créé en attente (PENDING) et l'expert
   * correspondant (s'il a un compte) est notifié. L'infirmier ne reçoit pas de
   * jeton tant que son inscription n'est pas validée.
   */
  async registerNurse(input: {
    fullName: string;
    email: string;
    password: string;
    phone?: string;
    healthFacility: string;
    professionalId?: string;
    supervisorMatricule: string;
  }) {
    const existing = await userDao.findByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const supervisorMatricule = input.supervisorMatricule.trim();
    const medecin = await medecinDao.findByMatricule(supervisorMatricule);
    if (!medecin) {
      throw new HttpError(
        422,
        'SUPERVISOR_MATRICULE_NOT_FOUND',
        "Le matricule de l'encadrant est introuvable dans le registre des médecins."
      );
    }

    const user = await userDao.create({
      fullName: input.fullName,
      email: input.email,
      password: input.password,
      role: 'NURSE',
      accountStatus: 'PENDING',
      supervisorMatricule,
      phone: input.phone,
      healthFacility: input.healthFacility,
      professionalId: input.professionalId
    });

    // Notifie l'expert encadrant s'il dispose déjà d'un compte.
    const supervisor = await userDao.findSpecialistByMatricule(supervisorMatricule);
    if (supervisor) {
      void notificationService.emit({
        recipientUserId: supervisor.id,
        type: 'NURSE_REGISTRATION_REQUEST',
        title: "Demande d'inscription infirmier",
        body: `${user.fullName} demande à rejoindre votre équipe.`,
        data: { nurseUserId: user.id }
      });
    }

    return {
      pending: true as const,
      fullName: user.fullName,
      email: user.email,
      message:
        "Inscription enregistrée. Votre encadrant doit valider votre compte avant que vous puissiez vous connecter."
    };
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

    if (user.accountStatus === 'PENDING') {
      throw new HttpError(
        403,
        'ACCOUNT_PENDING',
        "Votre inscription est en attente de validation par votre encadrant."
      );
    }
    if (user.accountStatus === 'REJECTED') {
      throw new HttpError(
        403,
        'ACCOUNT_REJECTED',
        user.rejectionReason
          ? `Votre inscription a été refusée : ${user.rejectionReason}`
          : 'Votre inscription a été refusée.'
      );
    }

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
