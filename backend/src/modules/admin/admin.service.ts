import type { ClinicalReferenceType, Role } from '@prisma/client';
import { HttpError, forbidden, notFound } from '../../common/errors/http-error.js';
import { userDao, toPublicUser } from '../users/user.dao.js';
import { patientDao } from '../patients/patient.dao.js';
import { consultationDao } from '../consultations/consultation.dao.js';
import { clinicalReferenceDao } from '../clinical-reference/clinical-reference.dao.js';
import { medecinDao } from '../medecins/medecin.dao.js';
import { adminDao } from './admin.dao.js';
import { facilityDao } from '../facilities/facility.dao.js';
import { auditDao } from '../audit/audit.service.js';
import { prisma } from '../../common/prisma.js';
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

    // Un soignant est rattaché à l'établissement indiqué (créé s'il est nouveau).
    const facility =
      input.role === 'NURSE' && input.healthFacility?.trim()
        ? await facilityDao.findOrCreate(input.healthFacility)
        : undefined;
    const user = await userDao.create({
      ...input,
      healthFacility: facility?.name ?? input.healthFacility,
      facilityId: facility?.id
    });
    return toPublicUser(user);
  },

  async updateUser(id: string, input: Partial<{ fullName: string; email: string; role: Role; phone?: string; healthFacility?: string; professionalId?: string }>) {
    const existing = await userDao.findById(id);
    if (!existing) throw notFound('Utilisateur introuvable');

    if (input.email && input.email.toLowerCase() !== existing.email) {
      const duplicate = await userDao.findByEmail(input.email);
      if (duplicate) throw new HttpError(409, 'EMAIL_ALREADY_EXISTS', 'Un utilisateur existe deja avec cet email');
    }

    const role = input.role ?? existing.role;
    const facility =
      role === 'NURSE' && input.healthFacility?.trim()
        ? await facilityDao.findOrCreate(input.healthFacility)
        : undefined;
    const user = await userDao.update(id, {
      fullName: input.fullName,
      email: input.email,
      role: input.role,
      phone: input.phone,
      healthFacility: facility?.name ?? input.healthFacility,
      facilityId: facility?.id,
      professionalId: input.professionalId
    });
    return toPublicUser(user);
  },

  /** Active un compte en attente (spécialiste inscrit depuis l'application, infirmier…). */
  async approveUser(id: string) {
    const existing = await userDao.findById(id);
    if (!existing) throw notFound('Utilisateur introuvable');
    if (existing.accountStatus !== 'PENDING') {
      throw new HttpError(409, 'ACCOUNT_NOT_PENDING', 'Ce compte n’est pas en attente de validation.');
    }
    return toPublicUser(await userDao.setAccountStatus(id, 'ACTIVE', null));
  },

  async rejectUser(id: string, reason?: string) {
    const existing = await userDao.findById(id);
    if (!existing) throw notFound('Utilisateur introuvable');
    if (existing.accountStatus !== 'PENDING') {
      throw new HttpError(409, 'ACCOUNT_NOT_PENDING', 'Ce compte n’est pas en attente de validation.');
    }
    return toPublicUser(await userDao.setAccountStatus(id, 'REJECTED', reason?.trim() || null));
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
    const { facilityId, ...patch } = input;
    if (facilityId && !(await facilityDao.findById(facilityId))) {
      throw new HttpError(422, 'FACILITY_NOT_FOUND', 'Établissement introuvable.');
    }
    return patientDao.update(id, patch, { facilityId });
  },

  listFacilities() {
    return facilityDao.listWithCounts();
  },

  /** Journal d'audit, du plus récent au plus ancien, avec les noms lisibles. */
  async listAudit(filter: { patientId?: string; actorUserId?: string; before?: Date; limit: number }) {
    const rows = await auditDao.list(filter);
    const actorIds = [...new Set(rows.map((r) => r.actorUserId).filter((v): v is string => Boolean(v)))];
    const patientIds = [...new Set(rows.map((r) => r.patientId).filter((v): v is string => Boolean(v)))];
    const [actors, patients] = await Promise.all([
      prisma.user.findMany({ where: { id: { in: actorIds } }, select: { id: true, fullName: true } }),
      prisma.patient.findMany({
        where: { id: { in: patientIds } },
        select: { id: true, firstName: true, lastName: true }
      })
    ]);
    const actorName = new Map(actors.map((a) => [a.id, a.fullName]));
    const patientName = new Map(patients.map((p) => [p.id, `${p.firstName} ${p.lastName}`]));
    return {
      entries: rows.map((row) => ({
        id: row.id,
        createdAt: row.createdAt.toISOString(),
        action: row.action,
        entityType: row.entityType,
        entityId: row.entityId,
        actorUserId: row.actorUserId,
        actorName: row.actorUserId ? actorName.get(row.actorUserId) ?? null : null,
        actorRole: row.actorRole,
        patientId: row.patientId,
        patientName: row.patientId ? patientName.get(row.patientId) ?? null : null,
        ip: row.ip,
        details: row.details
      })),
      nextBefore: rows.length === filter.limit ? rows[rows.length - 1]!.createdAt.toISOString() : null
    };
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
  },

  // --- Registre des médecins (source de vérité des matricules) ---

  listMedecins() {
    return medecinDao.list();
  },

  createMedecin(input: { matricule: string; nom: string; prenom: string }) {
    return medecinDao.create(input);
  },

  async updateMedecin(
    id: string,
    input: Partial<{ matricule: string; nom: string; prenom: string }>
  ) {
    const existing = await medecinDao.findById(id);
    if (!existing) throw notFound('Médecin introuvable');
    return medecinDao.update(id, input);
  },

  async deleteMedecin(id: string) {
    const existing = await medecinDao.findById(id);
    if (!existing) throw notFound('Médecin introuvable');
    await medecinDao.softDelete(id);
    return { deleted: true };
  }
};
