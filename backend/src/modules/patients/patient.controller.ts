import type { Request, Response } from 'express';
import { access } from '../../common/access/access-policy.js';
import { forbidden, notFound } from '../../common/errors/http-error.js';
import { audit } from '../audit/audit.service.js';
import { notificationService } from '../notifications/notification.service.js';
import { patientService } from './patient.service.js';

const CONSENT_FIELDS = ['consentForAi', 'consentForTeleExpertise'] as const;

export class PatientController {
  async list(req: Request, res: Response) {
    const patients = await patientService.listForUser(req.user!);
    void audit.fromRequest(req, {
      action: 'PATIENTS_LISTED',
      entityType: 'PATIENT',
      details: { count: patients.length }
    });
    res.json({ patients });
  }

  async create(req: Request, res: Response) {
    const patient = await patientService.create(req.user!, req.body);
    void audit.fromRequest(req, {
      action: 'PATIENT_CREATED',
      entityType: 'PATIENT',
      entityId: patient.id,
      patientId: patient.id,
      details: { consentForAi: patient.consentForAi, consentForTeleExpertise: patient.consentForTeleExpertise }
    });
    res.status(201).json({ patient });
  }

  async getById(req: Request, res: Response) {
    const id = String(req.params.id);
    await access.assertPatient(req.user!, id);
    const patient = await patientService.findById(id);
    if (!patient) throw notFound('Patient introuvable');
    void audit.fromRequest(req, { action: 'PATIENT_VIEWED', entityType: 'PATIENT', entityId: id, patientId: id });
    res.json({ patient });
  }

  async update(req: Request, res: Response) {
    const id = String(req.params.id);
    const user = req.user!;
    await access.assertPatient(user, id);
    const patient = await patientService.findById(id);
    if (!patient) throw notFound('Patient introuvable');

    const body = req.body as Record<string, unknown>;
    if (user.role === 'PATIENT') {
      delete body.isValidated;
      // Dossier validé : l'identité est figée, mais le patient garde la main sur
      // ses accords (les donner ou les retirer à tout moment).
      const identityChange = Object.keys(body).some((key) => !(CONSENT_FIELDS as readonly string[]).includes(key));
      if (patient.isValidated && identityChange) {
        throw forbidden('Dossier validé : seuls vos accords restent modifiables. Pour le reste, voyez votre soignant.');
      }
    }

    // Un soignant qui valide un patient inscrit seul l'accueille dans son établissement.
    const validating = !patient.isValidated && body.isValidated === true;
    const system =
      validating && user.role === 'NURSE' && !patient.facilityId && user.facilityId
        ? { facilityId: user.facilityId }
        : {};
    const updated = await patientService.update(id, body, system);

    const changed = Object.keys(body).filter(
      (key) => key !== 'isValidated' && !(CONSENT_FIELDS as readonly string[]).includes(key)
    );
    if (changed.length) {
      void audit.fromRequest(req, {
        action: 'PATIENT_UPDATED',
        entityType: 'PATIENT',
        entityId: id,
        patientId: id,
        details: { fields: changed }
      });
    }
    if (CONSENT_FIELDS.some((key) => body[key] !== undefined && body[key] !== patient[key])) {
      void audit.fromRequest(req, {
        action: 'PATIENT_CONSENT_CHANGED',
        entityType: 'PATIENT',
        entityId: id,
        patientId: id,
        details: { consentForAi: updated.consentForAi, consentForTeleExpertise: updated.consentForTeleExpertise }
      });
    }
    if (validating && updated.isValidated) {
      void audit.fromRequest(req, { action: 'PATIENT_VALIDATED', entityType: 'PATIENT', entityId: id, patientId: id });
    }

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
