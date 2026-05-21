import { Router } from 'express';
import { requireAuth, requireRoles } from '../auth/auth.middleware.js';
import { asyncHandler } from '../common/async-handler.js';
import { forbidden, notFound } from '../common/http-error.js';
import { validateBody } from '../common/validate.js';
import { createPatientSchema } from './patient.schemas.js';
import { patientService } from './patient.service.js';

export const patientRouter = Router();

patientRouter.use(requireAuth);

patientRouter.get(
  '/',
  requireRoles('NURSE', 'SPECIALIST', 'ADMIN'),
  asyncHandler(async (req, res) => {
    res.json({ patients: await patientService.listForUser(req.user!) });
  })
);

patientRouter.post(
  '/',
  requireRoles('NURSE', 'ADMIN'),
  validateBody(createPatientSchema),
  asyncHandler(async (req, res) => {
    const patient = await patientService.create(req.user!.id, req.body);
    res.status(201).json({ patient });
  })
);

patientRouter.get(
  '/:id',
  requireRoles('NURSE', 'SPECIALIST', 'ADMIN', 'PATIENT'),
  asyncHandler(async (req, res) => {
    if (req.user!.role === 'PATIENT' && req.user!.linkedPatientId !== req.params.id) {
      throw forbidden('Vous pouvez uniquement consulter votre propre dossier.');
    }
    const patient = await patientService.findById(String(req.params.id));
    if (!patient) throw notFound('Patient introuvable');
    res.json({ patient });
  })
);

patientRouter.patch(
  '/:id',
  asyncHandler(async (req, res) => {
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
    res.json({ patient: updated });
  })
);
