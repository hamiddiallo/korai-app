import assert from 'node:assert/strict';
import { afterEach, describe, it } from 'node:test';
import { Prisma } from '@prisma/client';
import { restoreStubs, stub } from './helpers.js';

const { consultationDao } = await import('../src/modules/consultations/consultation.dao.js');
const { consultationService } = await import('../src/modules/consultations/consultation.service.js');
const { patientDao } = await import('../src/modules/patients/patient.dao.js');
const { patientService } = await import('../src/modules/patients/patient.service.js');
const { clinicalReferenceDao } = await import('../src/modules/clinical-reference/clinical-reference.dao.js');

const uniqueViolation = () =>
  new Prisma.PrismaClientKnownRequestError('Unique constraint failed', { code: 'P2002', clientVersion: 'test' });

const record = {
  id: 'case-1',
  patientId: 'p-1',
  createdByUserId: 'nurse-1',
  earSide: 'LEFT',
  symptomIds: [],
  symptomLabels: [],
  medicalHistoryIds: [],
  medicalHistoryLabels: [],
  touchCheckIds: [],
  touchCheckLabels: [],
  clinicalNarrative: 'Otalgie',
  status: 'PENDING_AI',
  urgency: 'LOW',
  clientLocalId: 'local_abc',
  createdAt: new Date(0).toISOString(),
  updatedAt: new Date(0).toISOString()
} as any;

describe('envois simultanés d’une même consultation', () => {
  afterEach(restoreStubs);

  it('le second envoi renvoie la consultation du premier, sans doublon ni second appel IA', async () => {
    stub(patientDao, 'findById', (async () => ({ id: 'p-1' })) as any);
    stub(clinicalReferenceDao, 'dangerScoresByIds', (async () => new Map()) as any);
    let lookups = 0;
    stub(consultationDao, 'findByClientLocalId', (async () => (lookups++ === 0 ? undefined : record)) as any);
    stub(consultationDao, 'create', (async () => {
      throw uniqueViolation();
    }) as any);
    let aiCalls = 0;
    const { aiService } = await import('../src/modules/ai/ai.service.js');
    stub(aiService, 'ragAnalyze', (async () => {
      aiCalls++;
      return {};
    }) as any);

    const result = await consultationService.submitDiagnosis({
      createdByUserId: 'nurse-1',
      patientId: 'p-1',
      clinicalNarrative: 'Otalgie',
      urgency: 'LOW',
      earSide: 'LEFT',
      clientLocalId: 'local_abc',
      showSources: true,
      requestSpecialistReview: false,
      viewerRole: 'NURSE'
    } as any);
    assert.equal(result.id, 'case-1');
    assert.equal(aiCalls, 0);
  });

  it('fiche patient envoyée deux fois : la seconde renvoie la première', async () => {
    stub(patientDao, 'findByClientLocalId', (async () => undefined) as any);
    stub(patientDao, 'create', (async () => {
      throw uniqueViolation();
    }) as any);
    let calls = 0;
    stub(patientDao, 'findByClientLocalId', (async () => (calls++ === 0 ? undefined : { id: 'p-1' })) as any);
    const patient = await patientService.createIdempotent('nurse-1', {
      firstName: 'Awa',
      lastName: 'Diop',
      consentForAi: false,
      consentForTeleExpertise: false,
      clientLocalId: 'local_p'
    } as any);
    assert.equal(patient.id, 'p-1');
  });
});
