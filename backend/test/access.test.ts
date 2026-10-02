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
const { patientScope, consultationScope } = await import('../src/common/access/access-policy.js');
const { toLegacyOrlCase } = await import('../src/modules/consultations/consultation.types.js');

const nurseFann = makeUser({ id: 'nurse-fann', role: 'NURSE', facilityId: 'fac-fann' });

const patientRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'patient-1',
  userId: null,
  createdByUserId: 'nurse-autre',
  firstName: 'Awa',
  lastName: 'Diop',
  birthDate: null,
  sex: 'F',
  phone: null,
  address: null,
  consentForAi: true,
  consentForTeleExpertise: true,
  consentForAiAt: null,
  consentForTeleExpertiseAt: null,
  facilityId: 'fac-fann',
  isValidated: true,
  clientLocalId: null,
  clientMutationId: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  deletedAt: null,
  ...overrides
});

describe('périmètre d’accès aux dossiers', () => {
  it('soignant : son établissement, ses créations et les inscriptions à accueillir', () => {
    assert.deepEqual(patientScope(nurseFann), {
      OR: [{ facilityId: 'fac-fann' }, { createdByUserId: 'nurse-fann' }, { facilityId: null, isValidated: false }]
    });
  });

  it('soignant sans établissement : jamais les dossiers des établissements', () => {
    const scope = patientScope(makeUser({ id: 'n2', role: 'NURSE' }));
    assert.deepEqual(scope, { OR: [{ createdByUserId: 'n2' }, { facilityId: null, isValidated: false }] });
  });

  it('spécialiste : seulement les patients envoyés en télé-expertise', () => {
    const scope = patientScope(makeUser({ id: 'orl-1', role: 'SPECIALIST' })) as any;
    const expertise = scope.consultations.some.OR[1].expertiseRequest.is;
    assert.deepEqual(expertise.OR, [{ status: 'PENDING' }, { assignedToUserId: 'orl-1' }]);
    assert.deepEqual(scope.consultations.some.OR[0], { assignedSpecialistId: 'orl-1' });
  });

  it('patient : uniquement son propre dossier', () => {
    assert.deepEqual(patientScope(makeUser({ role: 'PATIENT', linkedPatientId: 'p-9' })), { id: 'p-9' });
    assert.deepEqual(
      consultationScope(makeUser({ id: 'u-9', role: 'PATIENT', linkedPatientId: 'p-9' })),
      { OR: [{ createdByUserId: 'u-9' }, { patientId: 'p-9' }] }
    );
  });

  it('administrateur : tout', () => {
    assert.deepEqual(patientScope(makeUser({ role: 'ADMIN' })), {});
    assert.deepEqual(consultationScope(makeUser({ role: 'ADMIN' })), {});
  });
});

describe('routes : accès limité par établissement', () => {
  let app: TestApp;
  let audits: any[];

  before(async () => {
    app = await startTestApp();
  });
  after(async () => {
    await app.close();
  });
  beforeEach(async () => {
    audits = await captureAudit();
    stub(prisma.patient, 'findFirst', (async () => patientRow()) as any);
  });
  afterEach(restoreStubs);

  it('dossier d’un autre établissement : refusé et tracé', async () => {
    await signInAs(nurseFann);
    await allowAccess(false);
    const res = await app.request('GET', '/patients/patient-1');
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'OUT_OF_SCOPE');
    await new Promise((r) => setImmediate(r));
    assert.equal(audits[0]?.action, 'ACCESS_DENIED');
    assert.equal(audits[0]?.actorUserId, 'nurse-fann');
    assert.deepEqual(audits[0]?.details, { method: 'GET', path: '/patients/patient-1', code: 'OUT_OF_SCOPE' });
  });

  it('dossier de son établissement : ouvert et tracé', async () => {
    await signInAs(nurseFann);
    await allowAccess(true);
    const res = await app.request('GET', '/patients/patient-1');
    assert.equal(res.status, 200);
    await new Promise((r) => setImmediate(r));
    assert.deepEqual(
      audits.map((a) => [a.action, a.patientId, a.actorUserId]),
      [['PATIENT_VIEWED', 'patient-1', 'nurse-fann']]
    );
  });

  it('la liste est filtrée en base selon le périmètre', async () => {
    await signInAs(nurseFann);
    let where: any;
    stub(prisma.patient, 'findMany', (async (args: any) => {
      where = args.where;
      return [];
    }) as any);
    const res = await app.request('GET', '/patients');
    assert.equal(res.status, 200);
    assert.deepEqual(where, { AND: [{ deletedAt: null }, patientScope(nurseFann)] });
  });

  it('un nouveau dossier est rattaché à l’établissement du soignant', async () => {
    await signInAs(nurseFann);
    let data: any;
    stub(prisma.patient, 'create', (async (args: any) => {
      data = args.data;
      return patientRow(args.data);
    }) as any);
    const res = await app.request('POST', '/patients', { firstName: 'Awa', lastName: 'Diop' });
    assert.equal(res.status, 201);
    assert.equal(data.facilityId, 'fac-fann');
    assert.equal(data.consentForAi, false, 'aucun accord supposé');
  });

  it('valider un patient inscrit seul l’accueille dans l’établissement', async () => {
    await signInAs(nurseFann);
    await allowAccess(true);
    stub(prisma.patient, 'findFirst', (async () => patientRow({ facilityId: null, isValidated: false })) as any);
    stub(prisma.patient, 'findUnique', (async () => patientRow({ facilityId: null, isValidated: false })) as any);
    let data: any;
    stub(prisma.patient, 'update', (async (args: any) => {
      data = args.data;
      return patientRow({ ...args.data });
    }) as any);
    const res = await app.request('PATCH', '/patients/patient-1', { isValidated: true });
    assert.equal(res.status, 200);
    assert.equal(data.facilityId, 'fac-fann');
    await new Promise((r) => setImmediate(r));
    assert.ok(audits.some((a) => a.action === 'PATIENT_VALIDATED'));
  });

  it('un patient ne peut pas préparer la consultation d’un autre patient', async () => {
    await signInAs(makeUser({ id: 'u-9', role: 'PATIENT', linkedPatientId: 'p-9' }));
    await allowAccess(false);
    let created = false;
    stub(prisma.consultation, 'create', (async () => {
      created = true;
      return {};
    }) as any);
    const res = await app.request('POST', '/cases/diagnose', {
      patientId: '00000000-0000-4000-8000-000000000001',
      symptoms: 'Otalgie droite depuis 3 jours'
    });
    assert.equal(res.status, 403);
    assert.equal(created, false);
  });

  it('patient : dossier validé, ses accords restent modifiables mais pas son identité', async () => {
    const self = makeUser({ id: 'u-9', role: 'PATIENT', linkedPatientId: 'patient-1' });
    await signInAs(self);
    await allowAccess(true);
    stub(prisma.patient, 'findUnique', (async () => patientRow()) as any);
    stub(prisma.patient, 'update', (async (args: any) => patientRow(args.data)) as any);

    const consent = await app.request('PATCH', '/patients/patient-1', { consentForTeleExpertise: false });
    assert.equal(consent.status, 200);
    const identity = await app.request('PATCH', '/patients/patient-1', { firstName: 'Autre' });
    assert.equal(identity.status, 403);
  });

  it('file du spécialiste : demandes en attente et dossiers qu’il a pris en charge', async () => {
    await signInAs(makeUser({ id: 'orl-1', role: 'SPECIALIST' }));
    let where: any;
    stub(prisma.expertiseRequest, 'findMany', (async (args: any) => {
      where = args.where;
      return [];
    }) as any);
    const res = await app.request('GET', '/expertise/inbox');
    assert.equal(res.status, 200);
    assert.deepEqual(where.OR, [{ status: 'PENDING' }, { status: 'IN_REVIEW', assignedToUserId: 'orl-1' }]);
  });
});

describe('résultat masqué au patient tant qu’il n’est pas partagé', () => {
  const consultation = {
    id: 'c-1',
    patientId: 'p-9',
    createdByUserId: 'u-9',
    earSide: 'LEFT',
    symptomIds: [],
    symptomLabels: [],
    medicalHistoryIds: [],
    medicalHistoryLabels: [],
    touchCheckIds: [],
    touchCheckLabels: [],
    clinicalNarrative: 'Otalgie',
    status: 'AI_COMPLETED',
    urgency: 'LOW',
    createdAt: new Date(0).toISOString(),
    updatedAt: new Date(0).toISOString(),
    aiResponse: {
      rawJson: { likely_diagnosis: 'Otite externe' },
      imageOpinion: null,
      ragOpinion: 'Otite externe probable',
      likelyDiagnosis: 'Otite externe',
      confidenceLabel: 'HIGH',
      warnings: [],
      sources: []
    }
  } as any;

  it('le patient ne reçoit ni la réponse brute ni l’analyse', () => {
    const asPatient = toLegacyOrlCase(consultation, 'PATIENT');
    assert.equal(asPatient.aiResponse, undefined);
    assert.equal(asPatient.organizedAiSummary, undefined);
    assert.equal(asPatient.effectiveSummary.patientVisible, false);
    assert.ok(!JSON.stringify(asPatient).includes('Otite externe'));
  });

  it('le soignant reçoit tout', () => {
    const asNurse = toLegacyOrlCase(consultation, 'NURSE');
    assert.equal(asNurse.organizedAiSummary?.likelyDiagnosis, 'Otite externe');
    assert.ok(asNurse.aiResponse);
  });
});
