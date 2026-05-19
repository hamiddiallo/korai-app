import jwt from 'jsonwebtoken';
import type { RequestHandler } from 'express';
import { env } from '../config/env.js';
import { forbidden, unauthorized } from '../common/http-error.js';
import { store } from '../common/data-store.js';
import { prisma } from '../common/prisma.js';
import type { Role } from '../types.js';

type JwtPayload = {
  sub: string;
  role: Role;
};

export const requireAuth: RequestHandler = async (req, _res, next) => {
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : undefined;
  if (!token) return next(unauthorized());

  try {
    const payload = jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
    let user = await store.findUserById(payload.sub);
    if (!user) return next(unauthorized('Session invalide'));

    // Self-healing database logic for PATIENT users with missing linkedPatientId
    if (user.role === 'PATIENT' && !user.linkedPatientId) {
      let patient = await prisma.patient.findUnique({ where: { userId: user.id } });
      if (!patient) {
        const names = user.fullName.split(' ');
        const firstName = names[0] || 'Patient';
        const lastName = names.slice(1).join(' ') || 'Korai';
        patient = await prisma.patient.create({
          data: {
            userId: user.id,
            createdByUserId: user.id,
            firstName,
            lastName,
            isValidated: false,
          }
        });
      }
      const updatedUser = await store.updateUser(user.id, { linkedPatientId: patient.id });
      if (updatedUser) {
        user = updatedUser;
      }
    }

    req.user = {
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      role: user.role,
      phone: user.phone,
      healthFacility: user.healthFacility,
      professionalId: user.professionalId,
      linkedPatientId: user.linkedPatientId,
      createdAt: user.createdAt
    };
    return next();
  } catch {
    return next(unauthorized('Token invalide ou expire'));
  }
};

export const requireRoles =
  (...roles: Role[]): RequestHandler =>
  (req, _res, next) => {
    if (!req.user) return next(unauthorized());
    if (!roles.includes(req.user.role)) return next(forbidden());
    return next();
  };
