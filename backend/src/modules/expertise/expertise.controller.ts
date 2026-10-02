import type { Request, Response } from 'express';
import { access } from '../../common/access/access-policy.js';
import { audit } from '../audit/audit.service.js';
import { assertCanRequestExpertise } from '../consultations/consultation.controller.js';
import { consultationService } from '../consultations/consultation.service.js';
import { expertiseService } from './expertise.service.js';

export class ExpertiseController {
  async inbox(req: Request, res: Response) {
    const items = await expertiseService.listInbox(req.user!);
    void audit.fromRequest(req, {
      action: 'EXPERTISE_INBOX_VIEWED',
      entityType: 'EXPERTISE',
      details: { count: items.length }
    });
    res.json({ items });
  }

  async request(req: Request, res: Response) {
    const consultationId = String(req.params.id);
    await assertCanRequestExpertise(req.user!, consultationId);
    const orlCase = await consultationService.requestSpecialistReview(
      consultationId,
      req.user!.id,
      req.body,
      req.user!.role
    );
    void audit.fromRequest(req, {
      action: 'EXPERTISE_REQUESTED',
      entityType: 'EXPERTISE',
      entityId: consultationId,
      patientId: orlCase.patientId
    });
    res.status(201).json({ case: orlCase });
  }

  async assign(req: Request, res: Response) {
    const consultationId = String(req.params.id);
    await access.assertConsultation(req.user!, consultationId);
    const expertise = await expertiseService.assignToReview(consultationId, req.user!.id);
    void audit.fromRequest(req, {
      action: 'EXPERTISE_ASSIGNED',
      entityType: 'EXPERTISE',
      entityId: consultationId
    });
    res.json({ expertise });
  }

  async submitReview(req: Request, res: Response) {
    const consultationId = String(req.params.id);
    await access.assertConsultation(req.user!, consultationId);
    const expertise = await expertiseService.submitReview(consultationId, req.user!.id, req.body);
    void audit.fromRequest(req, {
      action: 'EXPERTISE_COMPLETED',
      entityType: 'EXPERTISE',
      entityId: consultationId,
      details: { decision: req.body.decision }
    });
    res.json({ expertise });
  }
}

export const expertiseController = new ExpertiseController();
