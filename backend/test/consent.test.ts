import assert from 'node:assert/strict';
import { after, afterEach, before, beforeEach, describe, it } from 'node:test';
import {
  allowAccess,
  captureAudit,
  makeUser,
  restoreStubs,
  signInAs,
  startTestApp,
  stub,
  type TestApp
} from './helpers.js';

const { prisma } = await import('../src/common/prisma.js');
const { patientDao } = await import('../src/modules/patients/patient.dao.js');
const { consultationDao } = await import('../src/modules/consultations/consultation.dao.js');
const { consultationService } = await import('../src/modules/consultations/consultation.service.js');

const PATIENT_ID = '00000000-0000-4000-8000-000000000001';

const patient = (overrides: Record<string, unknown> = {}) => ({
  id: PATIENT_ID,
  createdByUserId: 'nurse-1',
  firstName: 'Awa',
  lastName: 'Diop',
  consentForAi: true,
  consentForTeleExpertise: true,
  facilityId: 'fac-1',
  isValidated: true,
  createdAt: new Date(0).toISOString(),
  updatedAt: new Date(0).toISOString(),
  ...overrides
});

const diagnoseBody = (extra: Record<string, unknown> = {}) => ({
  patientId: PATIENT_ID,
  symptoms: 'Otalgie droite depuis 3 jours',
  ...extra
});

describe('accords du patient appliqués par le serveur', () => {
  let app: TestApp;
  let submitted: number;

  before(async () => {
    app = await startTestApp();
  });
  after(async () => {
    await app.close();
  });
  beforeEach(async () => {
    submitted = 0;
    await allowAccess(true);
    await captureAudit();
    await signInAs(makeUser({ id: 'nurse-1', role: 'NURSE', facilityId: 'fac-1' }));
    stub(consultationService, 'submitDiagnosis', (async () => {
      submitted++;
      return { id: 'case-1', patientId: PATIENT_ID, status: 'AI_COMPLETED' };
    }) as any);
  });
  afterEach(restoreStubs);

  it('sans accord pour l’IA : rien n’est enregistré ni envoyé', async () => {
    stub(patientDao, 'findById', (async () => patient({ consentForAi: false })) as any);
    const res = await app.request('POST', '/cases/diagnose', diagnoseBody());
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'CONSENT_AI_REQUIRED');
    assert.match(res.body.error.message, /Recueillez son accord/);
    assert.equal(submitted, 0);
  });

  it('avis demandé sans accord de télé-expertise : refusé avant l’analyse', async () => {
    stub(patientDao, 'findById', (async () => patient({ consentForTeleExpertise: false })) as any);
    const res = await app.request('POST', '/cases/diagnose', diagnoseBody({ requestSpecialistReview: true }));
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'CONSENT_TELEEXPERTISE_REQUIRED');
    assert.equal(submitted, 0);
  });

  it('accord pour l’IA seul : l’analyse part, sans avis spécialiste', async () => {
    stub(patientDao, 'findById', (async () => patient({ consentForTeleExpertise: false })) as any);
    const res = await app.request('POST', '/cases/diagnose', diagnoseBody({ requestSpecialistReview: false }));
    assert.equal(res.status, 201);
    assert.equal(submitted, 1);
  });

  it('message adressé au patient lui-même', async () => {
    await signInAs(makeUser({ id: 'u-9', role: 'PATIENT', linkedPatientId: PATIENT_ID }));
    stub(patientDao, 'findById', (async () => patient({ consentForAi: false, isValidated: false })) as any);
    const res = await app.request('POST', '/cases/diagnose', diagnoseBody());
    assert.equal(res.status, 403);
    assert.match(res.body.error.message, /Activez cet accord dans votre profil/);
  });

  it('demande d’avis sur une consultation existante sans accord : refusée', async () => {
    stub(consultationDao, 'findById', (async () => ({ id: 'case-1', patientId: PATIENT_ID })) as any);
    stub(patientDao, 'findById', (async () => patient({ consentForTeleExpertise: false })) as any);
    let requested = false;
    stub(consultationService, 'requestSpecialistReview', (async () => {
      requested = true;
      return {};
    }) as any);
    const res = await app.request('POST', '/cases/case-1/expertise/request', {});
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'CONSENT_TELEEXPERTISE_REQUIRED');
    assert.equal(requested, false);
  });

  it('relance de l’analyse après retrait de l’accord : refusée', async () => {
    stub(consultationDao, 'findById', (async () => ({ id: 'case-1', patientId: PATIENT_ID })) as any);
    stub(patientDao, 'findById', (async () => patient({ consentForAi: false })) as any);
    const res = await app.request('POST', '/cases/case-1/diagnose/retry');
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'CONSENT_AI_REQUIRED');
  });

  it('première consultation d’un patient inscrit seul : il rejoint l’établissement', async () => {
    stub(patientDao, 'findById', (async () => patient({ facilityId: undefined, isValidated: false })) as any);
    const updates: any[] = [];
    stub(patientDao, 'update', (async (...args: any[]) => {
      updates.push(args);
      return patient();
    }) as any);
    const res = await app.request('POST', '/cases/diagnose', diagnoseBody());
    assert.equal(res.status, 201);
    assert.deepEqual(updates, [[PATIENT_ID, {}, { facilityId: 'fac-1' }]]);
  });
});

describe('date des accords', () => {
  afterEach(restoreStubs);

  const captureUpdate = (current: { consentForAi: boolean; consentForTeleExpertise: boolean }) => {
    const calls: any[] = [];
    stub(prisma.patient, 'findUnique', (async () => current) as any);
    stub(prisma.patient, 'update', (async (args: any) => {
      calls.push(args.data);
      return { ...patient(), ...args.data, createdAt: new Date(), updatedAt: new Date() };
    }) as any);
    return calls;
  };

  it('accord donné : daté ; accord retiré : date effacée', async () => {
    const calls = captureUpdate({ consentForAi: false, consentForTeleExpertise: true });
    await patientDao.update(PATIENT_ID, { consentForAi: true, consentForTeleExpertise: false });
    assert.ok(calls[0].consentForAiAt instanceof Date);
    assert.equal(calls[0].consentForTeleExpertiseAt, null);
  });

  it('accord inchangé : date d’origine conservée', async () => {
    const calls = captureUpdate({ consentForAi: true, consentForTeleExpertise: true });
    await patientDao.update(PATIENT_ID, { consentForAi: true, firstName: 'Awa' });
    assert.equal('consentForAiAt' in calls[0], false);
  });
});
