import { Router } from 'express';
import { z } from 'zod';
import { requireAuth, requireRoles } from '../auth/auth.middleware.js';
import { asyncHandler } from '../common/async-handler.js';
import { HttpError } from '../common/http-error.js';
import { prisma } from '../common/prisma.js';

const clinicalItemTypeSchema = z.enum(['SYMPTOM', 'MEDICAL_HISTORY', 'TOUCH_CHECK']);

export const clinicalRouter = Router();

clinicalRouter.use(requireAuth, requireRoles('NURSE', 'PATIENT', 'ADMIN'));

clinicalRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const type = req.query.type?.toString();
    if (type && !clinicalItemTypeSchema.safeParse(type).success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Type de referentiel clinique invalide');
    }

    const items = await prisma.clinicalReferenceItem.findMany({
      where: {
        isActive: true,
        ...(type ? { type } : {})
      },
      orderBy: [{ sortOrder: 'asc' }, { label: 'asc' }]
    });

    res.json({ items });
  })
);
