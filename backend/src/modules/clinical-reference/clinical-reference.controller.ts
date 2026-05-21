import type { Request, Response } from 'express';
import { HttpError } from '../../common/errors/http-error.js';
import { ClinicalReferenceType } from '@prisma/client';
import { clinicalReferenceService } from './clinical-reference.service.js';

export class ClinicalReferenceController {
  async list(req: Request, res: Response) {
    const typeParam = req.query.type?.toString();
    let type: ClinicalReferenceType | undefined;
    if (typeParam) {
      if (!Object.values(ClinicalReferenceType).includes(typeParam as ClinicalReferenceType)) {
        throw new HttpError(400, 'VALIDATION_ERROR', 'Type de referentiel clinique invalide');
      }
      type = typeParam as ClinicalReferenceType;
    }
    const items = await clinicalReferenceService.listForClinicalWorkflow(type);
    res.json({ items });
  }
}

export const clinicalReferenceController = new ClinicalReferenceController();
