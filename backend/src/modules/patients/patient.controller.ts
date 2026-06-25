import type { Request, Response } from 'express';
import { forbidden, notFound } from '../../common/errors/http-error.js';
import { notificationService } from '../notifications/notification.service.js';
import { patientService } from './patient.service.js';

export class PatientController {
  async list(req: Request, res: Response) {
    const patients = await patientService.listForUser(req.user!);
    res.json({ patients });
  }

  async create(req: Request, res: Response) {
    const patient = await patientService.create(req.user!.id, req.body);
    res.status(201).json({ patient });
  }

  async getById(req: Request, res: Response) {
    if (req.user!.role === 'PATIENT' && req.user!.linkedPatientId !== req.params.id) {
      throw forbidden('Vous pouvez uniquement consulter votre propre dossier.');
    }
    const patient = await patientService.findById(String(req.params.id));
    if (!patient) throw notFound('Patient introuvable');
    res.json({ patient });
  }

  async update(req: Request, res: Response) {
    const patient = await patientService.findById(String(req.params.id));
    if (!patient) throw notFound('Patient introuvable');

    if (req.user!.role === 'PATIENT') {
      if (req.user!.linkedPatientId !== req.params.id) {
        throw forbidden('Vous pouvez uniquement modifier votre propre fiche.');
      }
      if (patient.isValidated) {
        throw forbidden('Dossier validé : modification réservée au professionnel de santé.');
      }
      delete req.body.isValidated;
    } else if (req.user!.role !== 'NURSE' && req.user!.role !== 'ADMIN') {
      throw forbidden('Accès refusé.');
    }

    const updated = await patientService.update(String(req.params.id), req.body);

    // Notifie le patient lié lorsque son dossier vient d'être validé.
    if (!patient.isValidated && updated.isValidated && updated.userId) {
      void notificationService.emit({
        recipientUserId: updated.userId,
        type: 'PATIENT_VALIDATED',
        title: 'Dossier validé',
        body: 'Votre dossier a été validé par un professionnel de santé.',
        patientId: updated.id
      });
    }

    res.json({ patient: updated });
  }
}

export const patientController = new PatientController();
