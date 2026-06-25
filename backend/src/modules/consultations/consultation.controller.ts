import type { Request, Response } from 'express';
import { HttpError } from '../../common/errors/http-error.js';
import { consultationService } from './consultation.service.js';
import { patientService } from '../patients/patient.service.js';

export class ConsultationController {
  async list(req: Request, res: Response) {
    res.json({ cases: await consultationService.listForUser(req.user!) });
  }

  async diagnose(req: Request, res: Response) {
    const body = req.body;
    const baseInput = {
      createdByUserId: req.user!.id,
      patientId: body.patientId,
      clinicalNarrative: body.symptoms,
      clinicalNotes: body.clinicalNotes,
      urgency: body.urgency,
      earSide: body.earSide,
      symptomIds: body.symptomIds,
      symptomLabels: body.symptomLabels,
      medicalHistoryIds: body.medicalHistoryIds,
      medicalHistoryLabels: body.medicalHistoryLabels,
      touchCheckIds: body.touchCheckIds,
      touchCheckLabels: body.touchCheckLabels,
      touchObservations: body.touchObservations,
      clientLocalId: body.clientLocalId,
      clientMutationId: body.clientMutationId,
      imageDescription: body.imageDescription,
      clinicalFingerprint: body.clinicalFingerprint
    };

    if (req.user!.role === 'PATIENT') {
      const patient = await patientService.findById(body.patientId);
      if (!patient) throw new HttpError(404, 'NOT_FOUND', 'Patient introuvable');
      if (patient.isValidated) {
        throw new HttpError(
          403,
          'DOSSIER_VALIDATED',
          'Dossier validé : la pré-consultation ne peut plus être modifiée.'
        );
      }
    }

    const orlCase = await consultationService.submitDiagnosis({
      ...baseInput,
      image: req.file,
      showSources: body.showSources,
      requestSpecialistReview: body.requestSpecialistReview,
      viewerRole: req.user!.role
    });

    res.status(201).json({ case: orlCase });
  }

  async retryDiagnosis(req: Request, res: Response) {
    const orlCase = await consultationService.retryDiagnosis(
      String(req.params.id),
      req.user!
    );
    res.json({ case: orlCase });
  }

  async requestSpecialistReview(req: Request, res: Response) {
    res.json({
      case: await consultationService.requestSpecialistReview(
        String(req.params.id),
        req.user!.id,
        req.body,
        req.user!.role
      )
    });
  }

  async completeSpecialistReview(req: Request, res: Response) {
    res.json({
      case: await consultationService.completeSpecialistReview(
        String(req.params.id),
        req.user!.id,
        req.body,
        req.user!.role
      )
    });
  }
}

export const consultationController = new ConsultationController();
