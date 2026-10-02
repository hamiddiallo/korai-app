import type { Request, Response } from 'express';
import { HttpError } from '../../common/errors/http-error.js';
import { ClinicalReferenceType } from '@prisma/client';
import { audit, type AuditAction } from '../audit/audit.service.js';
import { adminService } from './admin.service.js';

const userAudit = (req: Request, action: AuditAction, id: string, details?: Record<string, string>) =>
  audit.fromRequest(req, { action, entityType: 'USER', entityId: id, details });

const patientAudit = (req: Request, action: AuditAction, id: string, details?: Record<string, string[]>) =>
  audit.fromRequest(req, { action, entityType: 'PATIENT', entityId: id, patientId: id, details });

export class AdminController {
  async listUsers(_req: Request, res: Response) {
    res.json({ users: await adminService.listUsers() });
  }

  async createUser(req: Request, res: Response) {
    const user = await adminService.createUser(req.body);
    void userAudit(req, 'ADMIN_USER_CREATED', user.id, { role: user.role });
    res.status(201).json({ user });
  }

  async updateUser(req: Request, res: Response) {
    const user = await adminService.updateUser(String(req.params.id), req.body);
    void userAudit(req, 'ADMIN_USER_UPDATED', user.id);
    res.json({ user });
  }

  async approveUser(req: Request, res: Response) {
    const user = await adminService.approveUser(String(req.params.id));
    void userAudit(req, 'ADMIN_USER_APPROVED', user.id);
    res.json({ user });
  }

  async rejectUser(req: Request, res: Response) {
    const user = await adminService.rejectUser(String(req.params.id), req.body.reason);
    void userAudit(req, 'ADMIN_USER_REJECTED', user.id);
    res.json({ user });
  }

  async deleteUser(req: Request, res: Response) {
    const result = await adminService.deleteUser(String(req.params.id), req.user!.id);
    void userAudit(req, 'ADMIN_USER_DELETED', String(req.params.id));
    res.json(result);
  }

  async listPatients(req: Request, res: Response) {
    const patients = await adminService.listPatients();
    void audit.fromRequest(req, { action: 'ADMIN_PATIENTS_LISTED', entityType: 'PATIENT', details: { count: patients.length } });
    res.json({ patients });
  }

  async listDeletedPatients(_req: Request, res: Response) {
    res.json({ patients: await adminService.listDeletedPatients() });
  }

  async updatePatient(req: Request, res: Response) {
    const patient = await adminService.updatePatient(String(req.params.id), req.body);
    void patientAudit(req, 'ADMIN_PATIENT_UPDATED', patient.id, { fields: Object.keys(req.body) });
    res.json({ patient });
  }

  async deletePatient(req: Request, res: Response) {
    const result = await adminService.deletePatient(String(req.params.id));
    void patientAudit(req, 'ADMIN_PATIENT_DELETED', String(req.params.id));
    res.json(result);
  }

  async restorePatient(req: Request, res: Response) {
    const patient = await adminService.restorePatient(String(req.params.id));
    void patientAudit(req, 'ADMIN_PATIENT_RESTORED', patient.id);
    res.json({ patient });
  }

  async listPatientConsultations(req: Request, res: Response) {
    const includeDeleted = req.query.includeDeleted === 'true';
    const consultations = await adminService.listPatientConsultations(String(req.params.id), includeDeleted);
    void patientAudit(req, 'ADMIN_PATIENT_CONSULTATIONS_VIEWED', String(req.params.id));
    res.json({ consultations });
  }

  async deleteConsultation(req: Request, res: Response) {
    const result = await adminService.deleteConsultation(String(req.params.id));
    void audit.fromRequest(req, { action: 'ADMIN_CONSULTATION_DELETED', entityType: 'CONSULTATION', entityId: String(req.params.id) });
    res.json(result);
  }

  async restoreConsultation(req: Request, res: Response) {
    const result = await adminService.restoreConsultation(String(req.params.id));
    void audit.fromRequest(req, { action: 'ADMIN_CONSULTATION_RESTORED', entityType: 'CONSULTATION', entityId: String(req.params.id) });
    res.json(result);
  }

  async listFacilities(_req: Request, res: Response) {
    res.json({ facilities: await adminService.listFacilities() });
  }

  async listAudit(req: Request, res: Response) {
    const text = (value: unknown) => (typeof value === 'string' && value.trim() ? value.trim() : undefined);
    const before = text(req.query.before);
    const beforeDate = before ? new Date(before) : undefined;
    if (beforeDate && Number.isNaN(beforeDate.getTime())) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Paramètre « before » invalide');
    }
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 200);
    const patientId = text(req.query.patientId);
    const page = await adminService.listAudit({ patientId, actorUserId: text(req.query.actorUserId), before: beforeDate, limit });
    void audit.fromRequest(req, { action: 'AUDIT_VIEWED', entityType: 'AUDIT', patientId });
    res.json(page);
  }

  async listClinicalItems(req: Request, res: Response) {
    const typeParam = req.query.type?.toString();
    let type: ClinicalReferenceType | undefined;
    if (typeParam) {
      if (!Object.values(ClinicalReferenceType).includes(typeParam as ClinicalReferenceType)) {
        throw new HttpError(400, 'VALIDATION_ERROR', 'Type de referentiel clinique invalide');
      }
      type = typeParam as ClinicalReferenceType;
    }
    res.json({ items: await adminService.listClinicalItems(type) });
  }

  async createClinicalItem(req: Request, res: Response) {
    res.status(201).json({ item: await adminService.createClinicalItem(req.body) });
  }

  async updateClinicalItem(req: Request, res: Response) {
    res.json({ item: await adminService.updateClinicalItem(String(req.params.id), req.body) });
  }

  async deleteClinicalItem(req: Request, res: Response) {
    res.json(await adminService.deleteClinicalItem(String(req.params.id)));
  }

  async listMedecins(_req: Request, res: Response) {
    res.json({ medecins: await adminService.listMedecins() });
  }

  async createMedecin(req: Request, res: Response) {
    res.status(201).json({ medecin: await adminService.createMedecin(req.body) });
  }

  async updateMedecin(req: Request, res: Response) {
    res.json({ medecin: await adminService.updateMedecin(String(req.params.id), req.body) });
  }

  async deleteMedecin(req: Request, res: Response) {
    res.json(await adminService.deleteMedecin(String(req.params.id)));
  }
}

export const adminController = new AdminController();
