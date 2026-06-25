import type { ClinicalReferenceType, Role } from '@prisma/client';
import { HttpError, forbidden, notFound } from '../../common/errors/http-error.js';
import { userDao, toPublicUser } from '../users/user.dao.js';
import { patientDao } from '../patients/patient.dao.js';
import { consultationDao } from '../consultations/consultation.dao.js';
import { clinicalReferenceDao } from '../clinical-reference/clinical-reference.dao.js';
import { adminDao } from './admin.dao.js';
import type { PatientRecord } from '../patients/patient.types.js';

export const adminService = {
  async listUsers() {
    const users = await userDao.list();
    return users.map(toPublicUser);
  },

  async createUser(input: {
    fullName: string;
    email: string;
    password: string;
    role: Role;
    phone?: string;
    healthFacility?: string;
    professionalId?: string;
  }) {
    const existing = await userDao.findByEmail(input.email);
    if (existing) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');

    const user = await userDao.create(input);
    return toPublicUser(user);
  },

  async updateUser(id: string, input: Partial<{ fullName: string; email: string; role: Role; phone?: string; healthFacility?: string; professionalId?: string }>) {
    const existing = await userDao.findById(id);
    if (!existing) throw notFound('Utilisateur introuvable');

    if (input.email && input.email.toLowerCase() !== existing.email) {
      const duplicate = await userDao.findByEmail(input.email);
      if (duplicate) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');
    }

    const user = await userDao.update(id, {
      fullName: input.fullName,
      email: input.email,
      role: input.role,
      phone: input.phone,
      healthFacility: input.healthFacility,
      professionalId: input.professionalId
    });
    return toPublicUser(user);
  },

  async deleteUser(id: string, currentUserId: string) {
    if (id === currentUserId) throw forbidden('Un admin ne peut pas supprimer son propre compte');

    const existing = await userDao.findById(id);
    if (!existing) throw notFound('Utilisateur introuvable');

    if (existing.role === 'ADMIN') {
      const admins = await adminDao.countUsersByRole('ADMIN');
      if (admins <= 1) throw forbidden('Impossible de supprimer le dernier compte admin');
    }

    const { linkedPatients, linkedConsultations } = await userDao.countLinkedClinicalData(id);
    if (linkedPatients > 0 || linkedConsultations > 0) {
      throw new HttpError(
        409,
        'USER_HAS_CLINICAL_DATA',
        'Ce compte est lie a des donnees cliniques et ne peut pas etre supprime'
      );
    }

    await userDao.delete(id);
    return { deleted: true };
  },

  async listPatients() {
    return patientDao.list();
  },

  async updatePatient(id: string, input: Partial<PatientRecord>) {
    const existing = await patientDao.findById(id);
    if (!existing) throw notFound('Patient introuvable');
    return patientDao.update(id, input);
  },

  async deletePatient(id: string) {
    const existing = await patientDao.findById(id);
    if (!existing) throw notFound('Patient introuvable');

    const consultations = await consultationDao.listForPatient(id);

    // Garde : on ne supprime pas un patient dont une consultation est en cours
    // d'expertise (présente dans la file d'un spécialiste). Le reste est en
    // soft-delete réversible (cf. restorePatient).
    const inReview = consultations.some(
      (c) => c.status === 'PENDING_SPECIALIST_REVIEW'
    );
    if (inReview) {
      throw new HttpError(
        409,
        'PATIENT_HAS_ACTIVE_REVIEW',
        "Ce patient a une consultation en cours d'expertise spécialiste et ne peut pas être supprimé."
      );
    }

    // Cascade soft-delete (réversible) sur toutes les consultations du patient.
    await Promise.all(consultations.map((c) => consultationDao.softDelete(c.id)));
    await patientDao.delete(id);
    return { deleted: true };
  },

  async restorePatient(id: string) {
    const patient = await patientDao.findByIdIncludingDeleted(id);
    if (!patient) throw notFound('Patient introuvable');

    // Cascade restore sur toutes les consultations soft-deleted du même patient
    const allConsultations = await consultationDao.listForPatient(id, true);
    await Promise.all(allConsultations.filter(c => c.deletedAt).map((c) => consultationDao.restore(c.id)));
    return patientDao.restore(id);
  },

  async listDeletedPatients() {
    return patientDao.listDeleted();
  },

  async listPatientConsultations(patientId: string, includeDeleted = false) {
    const existing = await patientDao.findById(patientId).catch(() => undefined);
    // allow lookup even if patient is soft-deleted
    return consultationDao.listForPatient(patientId, includeDeleted);
  },

  async deleteConsultation(id: string) {
    const existing = await consultationDao.findById(id);
    if (!existing) throw notFound('Consultation introuvable');
    await consultationDao.softDelete(id);
    return { deleted: true };
  },

  async restoreConsultation(id: string) {
    await consultationDao.restore(id);
    return { restored: true };
  },

  listClinicalItems(type?: ClinicalReferenceType) {
    return clinicalReferenceDao.listAll(type);
  },

  createClinicalItem(input: {
    type: ClinicalReferenceType;
    label: string;
    description?: string;
    isActive: boolean;
    sortOrder: number;
    dangerScore?: number;
  }) {
    return clinicalReferenceDao.create(input);
  },

  async updateClinicalItem(
    id: string,
    input: Partial<{ type: ClinicalReferenceType; label: string; description?: string; isActive: boolean; sortOrder: number; dangerScore: number }>
  ) {
    const existing = await clinicalReferenceDao.findById(id);
    if (!existing) throw notFound('Element clinique introuvable');
    return clinicalReferenceDao.update(id, input);
  },

  async deleteClinicalItem(id: string) {
    const existing = await clinicalReferenceDao.findById(id);
    if (!existing) throw notFound('Element clinique introuvable');
    await clinicalReferenceDao.delete(id);
    return { deleted: true };
  }
};
