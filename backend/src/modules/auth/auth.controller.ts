import type { Request, Response } from 'express';
import { HttpError } from '../../common/errors/http-error.js';
import { audit } from '../audit/audit.service.js';
import { authService } from './auth.service.js';

export class AuthController {
  async login(req: Request, res: Response) {
    const email = String(req.body.email ?? '').toLowerCase();
    try {
      const result = await authService.login(req.body);
      void audit.record({
        actorUserId: result.user.id,
        actorRole: result.user.role,
        action: 'AUTH_LOGIN_SUCCEEDED',
        entityType: 'AUTH',
        ip: req.ip
      });
      res.json(result);
    } catch (error) {
      if (error instanceof HttpError) {
        void audit.record({
          action: 'AUTH_LOGIN_FAILED',
          entityType: 'AUTH',
          ip: req.ip,
          details: { email, code: error.code }
        });
      }
      throw error;
    }
  }

  async refresh(req: Request, res: Response) {
    res.json(await authService.refresh(req.body.refreshToken));
  }

  async registerPatient(req: Request, res: Response) {
    res.status(201).json(await authService.registerPatient(req.body));
  }

  async registerNurse(req: Request, res: Response) {
    res.status(201).json(await authService.registerNurse(req.body));
  }

  async registerSpecialist(req: Request, res: Response) {
    res.status(201).json(await authService.registerSpecialist(req.body));
  }

  async register(req: Request, res: Response) {
    res.status(201).json(await authService.register(req.body));
  }

  me(req: Request, res: Response) {
    res.json({ user: req.user });
  }

  async updateProfile(req: Request, res: Response) {
    const updated = await authService.updateProfile(req.user!.id, req.body);
    res.json({ user: updated });
  }

  async updatePassword(req: Request, res: Response) {
    await authService.updatePassword(req.user!.id, req.body.currentPassword, req.body.newPassword);
    void audit.fromRequest(req, { action: 'AUTH_PASSWORD_CHANGED', entityType: 'USER', entityId: req.user!.id });
    res.json({ success: true });
  }
}

export const authController = new AuthController();
