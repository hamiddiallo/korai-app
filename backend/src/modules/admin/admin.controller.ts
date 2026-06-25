import type { Request, Response } from 'express';
import { HttpError } from '../../common/errors/http-error.js';
import { ClinicalReferenceType } from '@prisma/client';
import { adminService } from './admin.service.js';

export class AdminController {
  async listUsers(_req: Request, res: Response) {
    res.json({ users: await adminService.listUsers() });
  }

  async createUser(req: Request, res: Response) {
    res.status(201).json({ user: await adminService.createUser(req.body) });
  }

  async updateUser(req: Request, res: Response) {
    res.json({ user: await adminService.updateUser(String(req.params.id), req.body) });
  }

  async deleteUser(req: Request, res: Response) {
    res.json(await adminService.deleteUser(String(req.params.id), req.user!.id));
  }

  async listPatients(_req: Request, res: Response) {
    res.json({ patients: await adminService.listPatients() });
  }

  async listDeletedPatients(_req: Request, res: Response) {
    res.json({ patients: await adminService.listDeletedPatients() });
  }

  async updatePatient(req: Request, res: Response) {
    res.json({ patient: await adminService.updatePatient(String(req.params.id), req.body) });
  }

  async deletePatient(req: Request, res: Response) {
    res.json(await adminService.deletePatient(String(req.params.id)));
  }

  async restorePatient(req: Request, res: Response) {
    res.json({ patient: await adminService.restorePatient(String(req.params.id)) });
  }

  async listPatientConsultations(req: Request, res: Response) {
    const includeDeleted = req.query.includeDeleted === 'true';
    res.json({ consultations: await adminService.listPatientConsultations(String(req.params.id), includeDeleted) });
  }

  async deleteConsultation(req: Request, res: Response) {
    res.json(await adminService.deleteConsultation(String(req.params.id)));
  }

  async restoreConsultation(req: Request, res: Response) {
    res.json(await adminService.restoreConsultation(String(req.params.id)));
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
