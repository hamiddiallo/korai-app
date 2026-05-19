import { Router } from 'express';
import { requireAuth, requireRoles } from '../auth/auth.middleware.js';
import { asyncHandler } from '../common/async-handler.js';
import { HttpError } from '../common/http-error.js';
import { validateBody } from '../common/validate.js';
import {
  clinicalItemTypeSchema,
  createAdminUserSchema,
  createClinicalItemSchema,
  updateAdminPatientSchema,
  updateAdminUserSchema,
  updateClinicalItemSchema
} from './admin.schemas.js';
import { adminService } from './admin.service.js';

export const adminRouter = Router();

adminRouter.use(requireAuth, requireRoles('ADMIN'));

adminRouter.get(
  '/users',
  asyncHandler(async (_req, res) => {
    res.json({ users: await adminService.listUsers() });
  })
);

adminRouter.post(
  '/users',
  validateBody(createAdminUserSchema),
  asyncHandler(async (req, res) => {
    res.status(201).json({ user: await adminService.createUser(req.body) });
  })
);

adminRouter.patch(
  '/users/:id',
  validateBody(updateAdminUserSchema),
  asyncHandler(async (req, res) => {
    res.json({ user: await adminService.updateUser(String(req.params.id), req.body) });
  })
);

adminRouter.delete(
  '/users/:id',
  asyncHandler(async (req, res) => {
    res.json(await adminService.deleteUser(String(req.params.id), req.user!.id));
  })
);

adminRouter.get(
  '/patients',
  asyncHandler(async (_req, res) => {
    res.json({ patients: await adminService.listPatients() });
  })
);

adminRouter.patch(
  '/patients/:id',
  validateBody(updateAdminPatientSchema),
  asyncHandler(async (req, res) => {
    res.json({ patient: await adminService.updatePatient(String(req.params.id), req.body) });
  })
);

adminRouter.delete(
  '/patients/:id',
  asyncHandler(async (req, res) => {
    res.json(await adminService.deletePatient(String(req.params.id)));
  })
);

adminRouter.get(
  '/clinical-items',
  asyncHandler(async (req, res) => {
    const type = req.query.type?.toString();
    if (type && !clinicalItemTypeSchema.safeParse(type).success) {
      throw new HttpError(400, 'VALIDATION_ERROR', 'Type de referentiel clinique invalide');
    }
    res.json({ items: await adminService.listClinicalItems(type) });
  })
);

adminRouter.post(
  '/clinical-items',
  validateBody(createClinicalItemSchema),
  asyncHandler(async (req, res) => {
    res.status(201).json({ item: await adminService.createClinicalItem(req.body) });
  })
);

adminRouter.patch(
  '/clinical-items/:id',
  validateBody(updateClinicalItemSchema),
  asyncHandler(async (req, res) => {
    res.json({ item: await adminService.updateClinicalItem(String(req.params.id), req.body) });
  })
);

adminRouter.delete(
  '/clinical-items/:id',
  asyncHandler(async (req, res) => {
    res.json(await adminService.deleteClinicalItem(String(req.params.id)));
  })
);
