import assert from 'node:assert/strict';
import { after, afterEach, before, beforeEach, describe, it } from 'node:test';
import { captureAudit, makeUser, restoreStubs, signInAs, startTestApp, stub, type TestApp } from './helpers.js';
import { HttpError } from '../src/common/errors/http-error.js';

const { prisma } = await import('../src/common/prisma.js');
const { audit, auditDao } = await import('../src/modules/audit/audit.service.js');
const { authService } = await import('../src/modules/auth/auth.service.js');

const tick = () => new Promise((resolve) => setImmediate(resolve));

describe('journal d’audit', () => {
  let app: TestApp;
  let entries: any[];

  before(async () => {
    app = await startTestApp();
  });
  after(async () => {
    await app.close();
  });
  beforeEach(async () => {
    entries = await captureAudit();
  });
  afterEach(restoreStubs);

  it('connexion réussie et connexion refusée sont tracées', async () => {
    stub(authService, 'login', (async (input: { email: string }) => {
      if (input.email === 'bon@korai.test') {
        return { user: { id: 'u-1', role: 'NURSE' }, accessToken: 'a', refreshToken: 'r' };
      }
      throw new HttpError(401, 'UNAUTHORIZED', 'Email ou mot de passe incorrect');
    }) as any);

    assert.equal((await app.request('POST', '/auth/login', { email: 'bon@korai.test', password: 'MotDePasse1!' }, '')).status, 200);
    assert.equal((await app.request('POST', '/auth/login', { email: 'Faux@Korai.test', password: 'MotDePasse1!' }, '')).status, 401);
    await tick();
    assert.deepEqual(
      entries.map((e) => [e.action, e.actorUserId, e.details?.email]),
      [
        ['AUTH_LOGIN_SUCCEEDED', 'u-1', undefined],
        ['AUTH_LOGIN_FAILED', undefined, 'faux@korai.test']
      ]
    );
  });

  it('les consultations de listes sont regroupées (une entrée par 10 min)', async () => {
    const entry = { actorUserId: 'u-1', action: 'PATIENTS_LISTED', entityType: 'PATIENT' } as const;
    await audit.record(entry, 1_000);
    await audit.record(entry, 1_000 + 5 * 60_000);
    await audit.record(entry, 1_000 + 11 * 60_000);
    assert.equal(entries.length, 2);
  });

  it('une panne du journal ne fait jamais échouer l’action', async () => {
    stub(auditDao, 'create', (async () => {
      throw new Error('base indisponible');
    }) as typeof auditDao.create);
    const warn = console.warn;
    const warnings: string[] = [];
    console.warn = (message: string) => warnings.push(message);
    try {
      await audit.record({ actorUserId: 'u-1', action: 'PATIENT_VIEWED', entityType: 'PATIENT', patientId: 'p-1' });
    } finally {
      console.warn = warn;
    }
    assert.equal(warnings.length, 1);
    assert.ok(!warnings[0]!.includes('p-1'), 'pas d’identifiant patient dans les journaux serveur');
  });

  it('modification d’un dossier : noms de champs seulement, jamais les valeurs', async () => {
    await signInAs(makeUser({ id: 'nurse-1', role: 'NURSE' }));
    const { access } = await import('../src/common/access/access-policy.js');
    stub(access, 'canSeePatient', (async () => true) as any);
    const row = {
      id: 'p-1', userId: null, createdByUserId: 'nurse-1', firstName: 'Awa', lastName: 'Diop', birthDate: null,
      sex: 'F', phone: '770000000', address: null, consentForAi: true, consentForTeleExpertise: true,
      consentForAiAt: null, consentForTeleExpertiseAt: null, facilityId: null, isValidated: true,
      clientLocalId: null, clientMutationId: null, createdAt: new Date(), updatedAt: new Date(), deletedAt: null
    };
    stub(prisma.patient, 'findFirst', (async () => row) as any);
    stub(prisma.patient, 'findUnique', (async () => row) as any);
    stub(prisma.patient, 'update', (async (args: any) => ({ ...row, ...args.data })) as any);

    const res = await app.request('PATCH', '/patients/p-1', { phone: '771234567', consentForAi: false });
    assert.equal(res.status, 200);
    await tick();
    const updated = entries.find((e) => e.action === 'PATIENT_UPDATED');
    const consent = entries.find((e) => e.action === 'PATIENT_CONSENT_CHANGED');
    assert.deepEqual(updated.details, { fields: ['phone'] });
    assert.deepEqual(consent.details, { consentForAi: false, consentForTeleExpertise: true });
    assert.ok(!JSON.stringify(entries).includes('771234567'));
  });

  it('l’administrateur lit le journal avec des noms lisibles', async () => {
    await signInAs(makeUser({ id: 'admin-1', role: 'ADMIN' }));
    stub(auditDao, 'list', (async () => [
      {
        id: 'a-1', createdAt: new Date('2026-09-28T10:00:00Z'), action: 'PATIENT_VIEWED', entityType: 'PATIENT',
        entityId: 'p-1', actorUserId: 'nurse-1', actorRole: 'NURSE', patientId: 'p-1', ip: '::1', details: null
      }
    ]) as any);
    stub(prisma.user, 'findMany', (async () => [{ id: 'nurse-1', fullName: 'Hamid Diallo' }]) as any);
    stub(prisma.patient, 'findMany', (async () => [{ id: 'p-1', firstName: 'Awa', lastName: 'Diop' }]) as any);

    const res = await app.request('GET', '/admin/audit?patientId=p-1');
    assert.equal(res.status, 200);
    assert.equal(res.body.entries[0].actorName, 'Hamid Diallo');
    assert.equal(res.body.entries[0].patientName, 'Awa Diop');
    assert.equal(res.body.nextBefore, null);
    await tick();
    assert.ok(entries.some((e) => e.action === 'AUDIT_VIEWED'));
  });

  it('le journal est réservé aux administrateurs', async () => {
    await signInAs(makeUser({ role: 'NURSE' }));
    assert.equal((await app.request('GET', '/admin/audit')).status, 403);
  });
});
