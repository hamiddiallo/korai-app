import { Router } from 'express';
import { requireAuth, requireRoles } from '../../common/middleware/auth.middleware.js';
import { asyncHandler } from '../../common/utils/async-handler.js';
import { validateBody } from '../../common/middleware/validate.middleware.js';
import {
  createAdminUserSchema,
  createClinicalItemSchema,
  updateAdminPatientSchema,
  updateAdminUserSchema,
  updateClinicalItemSchema
} from './admin.schemas.js';
import { adminController } from './admin.controller.js';

export const adminRouter = Router();

adminRouter.use(requireAuth, requireRoles('ADMIN'));

adminRouter.get('/users', asyncHandler((req, res) => adminController.listUsers(req, res)));
adminRouter.post('/users', validateBody(createAdminUserSchema), asyncHandler((req, res) => adminController.createUser(req, res)));
adminRouter.patch('/users/:id', validateBody(updateAdminUserSchema), asyncHandler((req, res) => adminController.updateUser(req, res)));
adminRouter.delete('/users/:id', asyncHandler((req, res) => adminController.deleteUser(req, res)));

adminRouter.get('/patients', asyncHandler((req, res) => adminController.listPatients(req, res)));
adminRouter.patch('/patients/:id', validateBody(updateAdminPatientSchema), asyncHandler((req, res) => adminController.updatePatient(req, res)));
adminRouter.delete('/patients/:id', asyncHandler((req, res) => adminController.deletePatient(req, res)));

adminRouter.get('/clinical-items', asyncHandler((req, res) => adminController.listClinicalItems(req, res)));
adminRouter.post('/clinical-items', validateBody(createClinicalItemSchema), asyncHandler((req, res) => adminController.createClinicalItem(req, res)));
adminRouter.patch('/clinical-items/:id', validateBody(updateClinicalItemSchema), asyncHandler((req, res) => adminController.updateClinicalItem(req, res)));
adminRouter.delete('/clinical-items/:id', asyncHandler((req, res) => adminController.deleteClinicalItem(req, res)));
