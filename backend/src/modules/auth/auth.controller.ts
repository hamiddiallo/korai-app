import type { Request, Response } from 'express';
import { authService } from './auth.service.js';

export class AuthController {
  async login(req: Request, res: Response) {
    res.json(await authService.login(req.body));
  }

  async registerPatient(req: Request, res: Response) {
    res.status(201).json(await authService.registerPatient(req.body));
  }

  async registerNurse(req: Request, res: Response) {
    res.status(201).json(await authService.registerNurse(req.body));
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
    res.json({ success: true });
  }
}

export const authController = new AuthController();
