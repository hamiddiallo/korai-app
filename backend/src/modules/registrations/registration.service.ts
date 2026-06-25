import { forbidden, notFound } from '../../common/errors/http-error.js';
import type { AuthenticatedUser } from '../../common/types.js';
import { userDao, toPublicUser } from '../users/user.dao.js';
import type { UserRecord } from '../users/user.types.js';

/** Un spécialiste ne traite que ses propres infirmiers ; l'admin, tous. */
const ensureAuthority = (nurse: UserRecord, user: AuthenticatedUser) => {
  if (user.role === 'ADMIN') return;
  if (
    user.role === 'SPECIALIST' &&
    user.matricule &&
    nurse.supervisorMatricule === user.matricule
  ) {
    return;
  }
  throw forbidden("Vous ne pouvez pas traiter cette demande d'inscription.");
};

const loadNurse = async (nurseId: string) => {
  const nurse = await userDao.findById(nurseId);
  if (!nurse || nurse.role !== 'NURSE') throw notFound("Demande d'inscription introuvable");
  return nurse;
};

export const registrationService = {
  /** Demandes visibles : spécialiste → ses infirmiers ; admin → tous les PENDING. */
  async listNurseRequests(user: AuthenticatedUser) {
    if (user.role === 'ADMIN') {
      const nurses = await userDao.listNursesByStatus('PENDING');
      return nurses.map(toPublicUser);
    }
    if (user.role === 'SPECIALIST') {
      if (!user.matricule) return [];
      const nurses = await userDao.listNursesBySupervisorMatricule(user.matricule);
      return nurses.map(toPublicUser);
    }
    return [];
  },

  async approve(nurseId: string, user: AuthenticatedUser) {
    const nurse = await loadNurse(nurseId);
    ensureAuthority(nurse, user);
    const updated = await userDao.setAccountStatus(nurseId, 'ACTIVE', null);
    return toPublicUser(updated);
  },

  async reject(nurseId: string, user: AuthenticatedUser, reason?: string) {
    const nurse = await loadNurse(nurseId);
    ensureAuthority(nurse, user);
    const updated = await userDao.setAccountStatus(nurseId, 'REJECTED', reason ?? null);
    return toPublicUser(updated);
  }
};
