import type { Request, Response } from 'express';
import { registrationService } from './registration.service.js';

export const registrationController = {
  async list(req: Request, res: Response) {
    res.json({ requests: await registrationService.listNurseRequests(req.user!) });
  },

  async approve(req: Request, res: Response) {
    res.json({
      nurse: await registrationService.approve(String(req.params.id), req.user!)
    });
  },

  async reject(req: Request, res: Response) {
    res.json({
      nurse: await registrationService.reject(
        String(req.params.id),
        req.user!,
        typeof req.body?.reason === 'string' ? req.body.reason : undefined
      )
    });
  }
};
