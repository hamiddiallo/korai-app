import type { RequestHandler } from 'express';
import { forbidden, unauthorized } from '../errors/http-error.js';
import type { Role } from '../types.js';
import { authService } from '../../modules/auth/auth.service.js';

export const requireAuth: RequestHandler = async (req, _res, next) => {
  const header = req.headers.authorization;
  const token = header?.startsWith('Bearer ') ? header.slice('Bearer '.length) : undefined;
  if (!token) return next(unauthorized());

  try {
    req.user = await authService.resolveAuthenticatedUser(token);
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
