import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { afterEach, describe, it } from 'node:test';
import { restoreStubs, stub } from './helpers.js';

const { computeUrgency, isAbnormalTouchFinding, resolveUrgency } = await import(
  '../src/modules/consultations/urgency.js'
);
const { clinicalReferenceDao } = await import('../src/modules/clinical-reference/clinical-reference.dao.js');
const { consultationDao } = await import('../src/modules/consultations/consultation.dao.js');
const { patientDao } = await import('../src/modules/patients/patient.dao.js');
const { consultationService } = await import('../src/modules/consultations/consultation.service.js');

type Fixture = {
  cases: Array<{ name: string; signs: number[]; histories: number[]; expected: string }>;
  touchObservations: Array<{ observation: string | null; abnormal: boolean }>;
};
const fixture: Fixture = JSON.parse(
  readFileSync(new URL('./fixtures/urgency-cases.json', import.meta.url), 'utf8')
);

// Scores du référentiel de démonstration (seed.ts).
const SCORES = new Map([
  ['sym-otalgie', 1],
  ['sym-fievre', 2],
  ['hist-cholesteatome', 3],
  ['touch-mastoide', 3],
  ['touch-tragus', 1]
]);

const useReferenceScores = () => {
  const requested: string[][] = [];
  stub(clinicalReferenceDao, 'dangerScoresByIds', async (ids: string[]) => {
    requested.push(ids);
    return new Map(ids.filter((id) => SCORES.has(id)).map((id) => [id, SCORES.get(id)!]));
  });
  return requested;
};

describe('formule du niveau d’urgence (cas partagés avec l’app)', () => {
  for (const c of fixture.cases) {
    it(c.name, () => {
      assert.equal(computeUrgency(c.signs, c.histories), c.expected);
    });
  }

  it('résultats des vérifications au toucher', () => {
    for (const { observation, abnormal } of fixture.touchObservations) {
      assert.equal(isAbnormalTouchFinding(observation), abnormal, String(observation));
    }
  });
});

describe('urgence d’une consultation (scores en base)', () => {
  afterEach(restoreStubs);

  it('une vérification au toucher anormale compte comme un signe', async () => {
    useReferenceScores();
    const urgency = await resolveUrgency({
      touchCheckIds: ['touch-mastoide'],
      touchObservations: { 'touch-mastoide': 'Anormal — léger' }
    });
    assert.equal(urgency, 'HIGH');
  });

  it('un résultat normal ou absent ne compte pas', async () => {
    const requested = useReferenceScores();
    const urgency = await resolveUrgency({
      symptomIds: ['sym-otalgie'],
      touchCheckIds: ['touch-mastoide', 'touch-tragus'],
      touchObservations: { 'touch-mastoide': 'Normal (négatif)' }
    });
    assert.equal(urgency, 'LOW');
    assert.deepEqual(requested, [['sym-otalgie']]);
  });

  it('un antécédent grave avec un symptôme léger reste à « moyen »', async () => {
    useReferenceScores();
    const urgency = await resolveUrgency({ symptomIds: ['sym-otalgie'], medicalHistoryIds: ['hist-cholesteatome'] });
    assert.equal(urgency, 'MEDIUM');
  });

  it('un symptôme préoccupant sur antécédent grave passe à « élevé »', async () => {
    useReferenceScores();
    const urgency = await resolveUrgency({ symptomIds: ['sym-fievre'], medicalHistoryIds: ['hist-cholesteatome'] });
    assert.equal(urgency, 'HIGH');
  });

  it('la consultation enregistrée utilise le calcul du serveur, pas la valeur envoyée', async () => {
    useReferenceScores();
    stub(patientDao, 'findById', (async () => ({ id: 'patient-1' })) as any);
    let saved: { urgency?: string } | undefined;
    stub(consultationDao, 'create', (async (input: { urgency: string }) => {
      saved = input;
      throw new Error('arrêt du test après le calcul');
    }) as any);

    await assert.rejects(
      consultationService.createDraft({
        createdByUserId: 'nurse-1',
        patientId: 'patient-1',
        clinicalNarrative: 'Examen ORL',
        urgency: 'LOW',
        earSide: 'LEFT',
        touchCheckIds: ['touch-mastoide'],
        touchObservations: { 'touch-mastoide': 'Anormal — modéré' }
      }),
      /arrêt du test/
    );
    assert.equal(saved?.urgency, 'HIGH');
  });
});
