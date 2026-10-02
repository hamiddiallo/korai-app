import type { Request, Response } from 'express';
import { access } from '../../common/access/access-policy.js';
import { assertConsent } from '../../common/access/consent.js';
import { HttpError, notFound } from '../../common/errors/http-error.js';
import type { AuthenticatedUser } from '../../common/types.js';
import { audit } from '../audit/audit.service.js';
import { patientDao } from '../patients/patient.dao.js';
import { consultationService } from './consultation.service.js';
import { consultationDao } from './consultation.dao.js';
import { patientService } from '../patients/patient.service.js';
import { imageVault } from '../images/image-vault.js';
import { neutralImageFilename } from '../ai/ai.service.js';

/** Patient d'une consultation existante, pour vérifier ses accords. */
const patientOfConsultation = async (consultationId: string) => {
  const consultation = await consultationDao.findById(consultationId);
  if (!consultation) throw notFound('Consultation introuvable');
  const patient = await patientService.findById(consultation.patientId);
  if (!patient) throw notFound('Patient introuvable');
  return patient;
};

/** Demande d'avis : accès à la consultation et accord de télé-expertise requis. */
export const assertCanRequestExpertise = async (user: AuthenticatedUser, consultationId: string) => {
  await access.assertConsultation(user, consultationId);
  assertConsent(await patientOfConsultation(consultationId), 'TELE_EXPERTISE', user.role);
};

export class ConsultationController {
  async list(req: Request, res: Response) {
    const cases = await consultationService.listForUser(req.user!);
    void audit.fromRequest(req, {
      action: 'CONSULTATIONS_LISTED',
      entityType: 'CONSULTATION',
      details: { count: cases.length }
    });
    res.json({ cases });
  }

  async diagnose(req: Request, res: Response) {
    const body = req.body;
    const user = req.user!;
    const baseInput = {
      createdByUserId: user.id,
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

    // Un patient ne peut préparer que sa propre consultation ; un soignant,
    // celle d'un patient de son établissement.
    await access.assertPatient(user, body.patientId);
    const patient = await patientService.findById(body.patientId);
    if (!patient) throw new HttpError(404, 'NOT_FOUND', 'Patient introuvable');

    if (user.role === 'PATIENT' && patient.isValidated) {
      throw new HttpError(
        403,
        'DOSSIER_VALIDATED',
        'Dossier validé : la pré-consultation ne peut plus être modifiée.'
      );
    }

    // Rien n'est enregistré ni envoyé à l'IA sans l'accord du patient.
    assertConsent(patient, 'AI', user.role);
    if (body.requestSpecialistReview) assertConsent(patient, 'TELE_EXPERTISE', user.role);

    // Patient inscrit seul, pris en charge pour la première fois : il rejoint
    // l'établissement du soignant.
    if (user.role === 'NURSE' && !patient.facilityId && user.facilityId) {
      await patientDao.update(patient.id, {}, { facilityId: user.facilityId });
    }

    const orlCase = await consultationService.submitDiagnosis({
      ...baseInput,
      image: req.file,
      showSources: body.showSources,
      requestSpecialistReview: body.requestSpecialistReview,
      viewerRole: user.role
    });

    void audit.fromRequest(req, {
      action: 'CONSULTATION_CREATED',
      entityType: 'CONSULTATION',
      entityId: orlCase.id,
      patientId: patient.id,
      details: { withImage: Boolean(req.file), requestSpecialistReview: Boolean(body.requestSpecialistReview) }
    });
    res.status(201).json({ case: orlCase });
  }

  /** Photo du tympan, déchiffrée à la volée pour qui a accès à la consultation. */
  async image(req: Request, res: Response) {
    const id = String(req.params.id);
    await access.assertConsultation(req.user!, id);
    const photo = await consultationDao.findStoredImage(id, String(req.params.imageId));
    if (!photo?.storageKey) throw notFound('Photo introuvable');
    const bytes = await imageVault.read(photo.storageKey);
    const consultation = await consultationDao.findById(id);
    void audit.fromRequest(req, {
      action: 'IMAGE_VIEWED',
      entityType: 'CONSULTATION',
      entityId: id,
      patientId: consultation?.patientId
    });
    res.set({
      'Content-Type': photo.mimeType,
      'Content-Disposition': `inline; filename="${neutralImageFilename(photo.mimeType)}"`,
      // Donnée de santé : jamais gardée en cache (navigateur, proxy).
      'Cache-Control': 'private, no-store'
    });
    res.send(bytes);
  }

  async retryDiagnosis(req: Request, res: Response) {
    const id = String(req.params.id);
    await access.assertConsultation(req.user!, id);
    const patient = await patientOfConsultation(id);
    assertConsent(patient, 'AI', req.user!.role);

    const orlCase = await consultationService.retryDiagnosis(id, req.user!);
    void audit.fromRequest(req, {
      action: 'CONSULTATION_AI_RETRIED',
      entityType: 'CONSULTATION',
      entityId: id,
      patientId: patient.id
    });
    res.json({ case: orlCase });
  }

  async requestSpecialistReview(req: Request, res: Response) {
    const id = String(req.params.id);
    await assertCanRequestExpertise(req.user!, id);
    const orlCase = await consultationService.requestSpecialistReview(id, req.user!.id, req.body, req.user!.role);
    void audit.fromRequest(req, {
      action: 'EXPERTISE_REQUESTED',
      entityType: 'EXPERTISE',
      entityId: id,
      patientId: orlCase.patientId
    });
    res.json({ case: orlCase });
  }

  async completeSpecialistReview(req: Request, res: Response) {
    const id = String(req.params.id);
    await access.assertConsultation(req.user!, id);
    const orlCase = await consultationService.completeSpecialistReview(id, req.user!.id, req.body, req.user!.role);
    void audit.fromRequest(req, {
      action: 'EXPERTISE_COMPLETED',
      entityType: 'EXPERTISE',
      entityId: id,
      patientId: orlCase.patientId,
      details: { decision: req.body.decision }
    });
    res.json({ case: orlCase });
  }
}

export const consultationController = new ConsultationController();
