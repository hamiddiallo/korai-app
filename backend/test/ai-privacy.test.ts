import assert from 'node:assert/strict';
import { afterEach, describe, it } from 'node:test';
import { restoreStubs, stub } from './helpers.js';

const { aiService, redactIdentityForExternalAi, neutralImageFilename } = await import('../src/modules/ai/ai.service.js');

const narrative = [
  'Patient: Awa Diop (Autodéclaration)',
  'Age: 34 ans',
  'Sexe: F',
  'Telephone: 77 123 45 67',
  'Adresse: Sacré-Cœur 3, Dakar',
  'Symptomes: Otalgie, Otorrhée',
  'Notes libres: douleur depuis 3 jours'
].join('\n');

describe('données envoyées au service IA externe', () => {
  afterEach(restoreStubs);

  it('retire nom, téléphone et adresse, garde les données cliniques', () => {
    const redacted = redactIdentityForExternalAi(narrative);
    for (const identity of ['Awa', 'Diop', '77 123', 'Dakar']) assert.ok(!redacted.includes(identity), identity);
    for (const clinical of ['Age: 34 ans', 'Sexe: F', 'Otalgie', 'douleur depuis 3 jours']) {
      assert.ok(redacted.includes(clinical), clinical);
    }
  });

  it('variantes accentuées et majuscules également retirées', () => {
    const redacted = redactIdentityForExternalAi('PATIENT : X\nTéléphone: 1\nNom: Y\nPrénom: Z\nOtalgie');
    assert.equal(redacted, 'Otalgie');
  });

  it('ragAnalyze n’envoie pas l’identité sur le réseau', async () => {
    let sentBody = '';
    stub(globalThis, 'fetch', (async (_url: unknown, init?: RequestInit) => {
      sentBody = String(init?.body ?? '');
      return new Response(JSON.stringify({ likely_diagnosis: 'Otite externe' }), {
        status: 200,
        headers: { 'content-type': 'application/json' }
      });
    }) as typeof fetch);
    await aiService.ragAnalyze({ symptoms: narrative });
    const decoded = new URLSearchParams(sentBody).get('symptoms') ?? '';
    assert.ok(decoded.includes('Otalgie'));
    assert.ok(!decoded.includes('Awa') && !decoded.includes('Dakar') && !decoded.includes('77 123'));
  });

  it('nom de fichier neutre pour la photo', () => {
    assert.equal(neutralImageFilename('image/jpeg'), 'otoscopie.jpg');
    assert.equal(neutralImageFilename('image/png'), 'otoscopie.png');
  });
});
