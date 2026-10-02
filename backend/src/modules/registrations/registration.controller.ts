import type { Request, Response } from 'express';
import { audit } from '../audit/audit.service.js';
import { registrationService } from './registration.service.js';

export const registrationController = {
  async list(req: Request, res: Response) {
    res.json({ requests: await registrationService.listNurseRequests(req.user!) });
  },

  async approve(req: Request, res: Response) {
    const nurse = await registrationService.approve(String(req.params.id), req.user!);
    void audit.fromRequest(req, { action: 'NURSE_REGISTRATION_APPROVED', entityType: 'USER', entityId: nurse.id });
    res.json({ nurse });
  },

  async reject(req: Request, res: Response) {
    const nurse = await registrationService.reject(
      String(req.params.id),
      req.user!,
      typeof req.body?.reason === 'string' ? req.body.reason : undefined
    );
    void audit.fromRequest(req, { action: 'NURSE_REGISTRATION_REJECTED', entityType: 'USER', entityId: nurse.id });
    res.json({ nurse });
  }
};
