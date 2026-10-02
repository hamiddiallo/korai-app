import assert from 'node:assert/strict';
import { after, afterEach, before, beforeEach, describe, it } from 'node:test';
import { makeUser, restoreStubs, signInAs, startTestApp, stub, type TestApp } from './helpers.js';

const { prisma } = await import('../src/common/prisma.js');
const { patientDao } = await import('../src/modules/patients/patient.dao.js');

const patientRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'patient-1',
  userId: 'user-patient',
  createdByUserId: 'user-patient', // un patient inscrit depuis l'app est son propre « créateur »
  firstName: 'Awa',
  lastName: 'Diop',
  birthDate: null,
  sex: 'F',
  phone: null,
  address: null,
  consentForAi: true,
  consentForTeleExpertise: true,
  isValidated: false,
  clientLocalId: null,
  clientMutationId: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  deletedAt: null,
  ...overrides
});

describe('PATCH /patients/:id — champs modifiables', () => {
  let app: TestApp;
  let updateCalls: any[];

  before(async () => {
    app = await startTestApp();
  });
  after(async () => {
    await app.close();
  });
  beforeEach(() => {
    updateCalls = [];
    stub(prisma.patient, 'findFirst', (async () => patientRow()) as any);
    stub(prisma.patient, 'update', (async (args: any) => {
      updateCalls.push(args);
      return patientRow(args.data);
    }) as any);
  });
  afterEach(restoreStubs);

  it('refuse une écriture imbriquée qui donnerait le rôle ADMIN (élévation de privilèges)', async () => {
    await signInAs(makeUser({ id: 'user-patient', role: 'PATIENT', linkedPatientId: 'patient-1' }));
    const res = await app.request('PATCH', '/patients/patient-1', {
      firstName: 'Awa',
      creator: { update: { role: 'ADMIN' } }
    });
    assert.equal(res.status, 400);
    assert.equal(res.body.error.code, 'VALIDATION_ERROR');
    assert.equal(updateCalls.length, 0, 'aucune écriture en base');
  });

  it('refuse les champs techniques (createdByUserId, deletedAt, consultations)', async () => {
    await signInAs(makeUser({ role: 'NURSE' }));
    for (const body of [{ createdByUserId: 'autre' }, { deletedAt: null }, { consultations: { deleteMany: {} } }]) {
      const res = await app.request('PATCH', '/patients/patient-1', body);
      assert.equal(res.status, 400, JSON.stringify(body));
    }
    assert.equal(updateCalls.length, 0);
  });

  it('accepte une mise à jour légitime du patient, sans lui laisser valider son dossier', async () => {
    await signInAs(makeUser({ id: 'user-patient', role: 'PATIENT', linkedPatientId: 'patient-1' }));
    const res = await app.request('PATCH', '/patients/patient-1', {
      firstName: 'Awa',
      lastName: 'Diop',
      birthDate: null,
      sex: 'F',
      isValidated: true
    });
    assert.equal(res.status, 200);
    assert.equal(updateCalls.length, 1);
    assert.deepEqual(updateCalls[0].data, { firstName: 'Awa', lastName: 'Diop', birthDate: null, sex: 'F' });
  });

  it('interdit la modification aux spécialistes', async () => {
    await signInAs(makeUser({ role: 'SPECIALIST' }));
    const res = await app.request('PATCH', '/patients/patient-1', { firstName: 'X' });
    assert.equal(res.status, 403);
    assert.equal(updateCalls.length, 0);
  });

  it('le DAO ne transmet à Prisma que les champs autorisés', async () => {
    await patientDao.update('patient-1', { firstName: 'Awa', creator: { update: { role: 'ADMIN' } } } as any);
    assert.deepEqual(updateCalls[0].data, { firstName: 'Awa' });
  });
});
