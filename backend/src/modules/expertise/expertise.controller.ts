import type { Request, Response } from 'express';
import { consultationService } from '../consultations/consultation.service.js';
import { expertiseService } from './expertise.service.js';

export class ExpertiseController {
  async inbox(req: Request, res: Response) {
    res.json({ items: await expertiseService.listInbox() });
  }

  async request(req: Request, res: Response) {
    const consultationId = String(req.params.id);
    const orlCase = await consultationService.requestSpecialistReview(
      consultationId,
      req.user!.id,
      req.body,
      req.user!.role
    );
    res.status(201).json({ case: orlCase });
  }

  async assign(req: Request, res: Response) {
    const expertise = await expertiseService.assignToReview(String(req.params.id), req.user!.id);
    res.json({ expertise });
  }

  async submitReview(req: Request, res: Response) {
    const expertise = await expertiseService.submitReview(
      String(req.params.id),
      req.user!.id,
      req.body
    );
    res.json({ expertise });
  }
}

export const expertiseController = new ExpertiseController();
