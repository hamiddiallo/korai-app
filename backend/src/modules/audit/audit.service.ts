import type { Prisma, Role } from '@prisma/client';
import type { Request } from 'express';
import { prisma } from '../../common/prisma.js';

/**
 * Journal d'audit : qui a consulté ou modifié quoi, et quand.
 * Jamais de donnée de santé dans `details` : identifiants, noms de champs,
 * booléens d'accord uniquement.
 */
export const AUDIT_ACTIONS = [
  'AUTH_LOGIN_SUCCEEDED',
  'AUTH_LOGIN_FAILED',
  'AUTH_PASSWORD_CHANGED',
  'ACCESS_DENIED',
  'PATIENTS_LISTED',
  'PATIENT_CREATED',
  'PATIENT_VIEWED',
  'PATIENT_UPDATED',
  'PATIENT_CONSENT_CHANGED',
  'PATIENT_VALIDATED',
  'CONSULTATIONS_LISTED',
  'CONSULTATION_CREATED',
  'CONSULTATION_AI_RETRIED',
  'IMAGE_VIEWED',
  'EXPERTISE_INBOX_VIEWED',
  'EXPERTISE_REQUESTED',
  'EXPERTISE_ASSIGNED',
  'EXPERTISE_COMPLETED',
  'NURSE_REGISTRATION_APPROVED',
  'NURSE_REGISTRATION_REJECTED',
  'ADMIN_USER_CREATED',
  'ADMIN_USER_UPDATED',
  'ADMIN_USER_DELETED',
  'ADMIN_USER_APPROVED',
  'ADMIN_USER_REJECTED',
  'ADMIN_PATIENTS_LISTED',
  'ADMIN_PATIENT_UPDATED',
  'ADMIN_PATIENT_DELETED',
  'ADMIN_PATIENT_RESTORED',
  'ADMIN_PATIENT_CONSULTATIONS_VIEWED',
  'ADMIN_CONSULTATION_DELETED',
  'ADMIN_CONSULTATION_RESTORED',
  'AUDIT_VIEWED'
] as const;
export type AuditAction = (typeof AUDIT_ACTIONS)[number];

/** Consultations de listes : une entrée par personne et par action toutes les 10 min. */
const COALESCED: ReadonlySet<AuditAction> = new Set([
  'PATIENTS_LISTED',
  'CONSULTATIONS_LISTED',
  'EXPERTISE_INBOX_VIEWED',
  'ADMIN_PATIENTS_LISTED',
  'AUDIT_VIEWED',
  'IMAGE_VIEWED'
]);
const COALESCE_MS = 10 * 60 * 1000;
const lastListed = new Map<string, number>();

export type AuditEntryInput = {
  actorUserId?: string;
  actorRole?: Role;
  action: AuditAction;
  entityType: 'AUTH' | 'PATIENT' | 'CONSULTATION' | 'EXPERTISE' | 'USER' | 'AUDIT';
  entityId?: string;
  patientId?: string;
  ip?: string;
  details?: Record<string, string | number | boolean | string[] | null>;
};

export const auditDao = {
  async create(entry: AuditEntryInput) {
    await prisma.auditLog.create({
      data: { ...entry, details: entry.details as Prisma.InputJsonValue | undefined }
    });
  },

  async list(filter: { patientId?: string; actorUserId?: string; before?: Date; limit: number }) {
    return prisma.auditLog.findMany({
      where: {
        ...(filter.patientId ? { patientId: filter.patientId } : {}),
        ...(filter.actorUserId ? { actorUserId: filter.actorUserId } : {}),
        ...(filter.before ? { createdAt: { lt: filter.before } } : {})
      },
      orderBy: { createdAt: 'desc' },
      take: filter.limit
    });
  }
};

export const audit = {
  /**
   * Enregistre une entrée sans jamais faire échouer l'action auditée : une
   * erreur d'écriture est signalée dans les journaux du serveur (sans données
   * patient) et la requête continue.
   */
  async record(entry: AuditEntryInput, now = Date.now()) {
    if (COALESCED.has(entry.action) && entry.actorUserId) {
      const key = `${entry.actorUserId}:${entry.action}:${entry.patientId ?? ''}`;
      const last = lastListed.get(key);
      if (last !== undefined && now - last < COALESCE_MS) return;
      lastListed.set(key, now);
    }
    try {
      await auditDao.create(entry);
    } catch (error) {
      console.warn(`Journal d'audit : écriture impossible (${entry.action}) — ${(error as Error).message}`);
    }
  },

  /** Entrée au nom de l'utilisateur de la requête (acteur, rôle, adresse IP). */
  fromRequest(req: Request, entry: Omit<AuditEntryInput, 'actorUserId' | 'actorRole' | 'ip'>) {
    return this.record({ ...entry, actorUserId: req.user?.id, actorRole: req.user?.role, ip: req.ip });
  },

  /** Réservé aux tests : oublie le regroupement des consultations de listes. */
  resetCoalescing() {
    lastListed.clear();
  }
};
