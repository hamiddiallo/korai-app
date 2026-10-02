import type { Prisma } from '@prisma/client';
import { HttpError } from '../errors/http-error.js';
import { prisma } from '../prisma.js';
import type { AuthenticatedUser } from '../types.js';

/**
 * Qui peut consulter quel dossier (besoin d'en connaître) :
 *   - administrateur : tout ;
 *   - soignant : les patients de son établissement, ceux qu'il a créés, et les
 *     patients inscrits seuls pas encore rattachés ni validés (à accueillir) ;
 *   - spécialiste : uniquement les consultations envoyées en télé-expertise
 *     (file commune) ou qui lui sont attribuées, et les patients concernés ;
 *   - patient : son propre dossier.
 * Une seule définition, utilisée pour les listes (filtre en base) comme pour
 * l'accès à un dossier précis.
 */
const specialistConsultations = (user: AuthenticatedUser): Prisma.ConsultationWhereInput => ({
  OR: [
    { assignedSpecialistId: user.id },
    {
      expertiseRequest: {
        is: { deletedAt: null, OR: [{ status: 'PENDING' }, { assignedToUserId: user.id }] }
      }
    }
  ]
});

export const patientScope = (user: AuthenticatedUser): Prisma.PatientWhereInput => {
  switch (user.role) {
    case 'ADMIN':
      return {};
    case 'NURSE':
      return {
        OR: [
          ...(user.facilityId ? [{ facilityId: user.facilityId }] : []),
          { createdByUserId: user.id },
          { facilityId: null, isValidated: false }
        ]
      };
    case 'SPECIALIST':
      return { consultations: { some: { deletedAt: null, ...specialistConsultations(user) } } };
    case 'PATIENT':
      return user.linkedPatientId ? { id: user.linkedPatientId } : { userId: user.id };
    default:
      return { id: '__aucun__' };
  }
};

export const consultationScope = (user: AuthenticatedUser): Prisma.ConsultationWhereInput => {
  switch (user.role) {
    case 'ADMIN':
      return {};
    case 'NURSE':
      return { OR: [{ createdByUserId: user.id }, { patient: { is: patientScope(user) } }] };
    case 'SPECIALIST':
      return specialistConsultations(user);
    case 'PATIENT':
      return {
        OR: [{ createdByUserId: user.id }, ...(user.linkedPatientId ? [{ patientId: user.linkedPatientId }] : [])]
      };
    default:
      return { id: '__aucun__' };
  }
};

const outOfScope = (what: 'patient' | 'consultation') =>
  new HttpError(
    403,
    'OUT_OF_SCOPE',
    what === 'patient'
      ? 'Ce dossier n’est pas accessible depuis votre compte.'
      : 'Cette consultation n’est pas accessible depuis votre compte.'
  );

export const access = {
  async canSeePatient(user: AuthenticatedUser, patientId: string) {
    if (user.role === 'ADMIN') return true;
    const count = await prisma.patient.count({
      where: { AND: [{ id: patientId, deletedAt: null }, patientScope(user)] }
    });
    return count > 0;
  },

  async canSeeConsultation(user: AuthenticatedUser, consultationId: string) {
    if (user.role === 'ADMIN') return true;
    const count = await prisma.consultation.count({
      where: { AND: [{ id: consultationId, deletedAt: null }, consultationScope(user)] }
    });
    return count > 0;
  },

  async assertPatient(user: AuthenticatedUser, patientId: string) {
    if (!(await this.canSeePatient(user, patientId))) throw outOfScope('patient');
  },

  async assertConsultation(user: AuthenticatedUser, consultationId: string) {
    if (!(await this.canSeeConsultation(user, consultationId))) throw outOfScope('consultation');
  }
};
