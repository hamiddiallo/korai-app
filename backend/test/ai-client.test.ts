import assert from 'node:assert/strict';
import { afterEach, describe, it } from 'node:test';
import { restoreStubs, stub } from './helpers.js';

const { env } = await import('../src/config/env.js');
const { aiService, describeAiError, isRetryableAiError } = await import('../src/modules/ai/ai.service.js');

const photo = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4, 0xff, 0xd9]);
const image = { buffer: photo, mimetype: 'image/jpeg', originalname: 'Awa_Diop.jpg', size: photo.length } as Express.Multer.File;

type Sent = { url: string; init: RequestInit; headers: Record<string, string> };

/** Remplace le réseau : garde la requête envoyée au service IA et renvoie `response`. */
const captureFetch = (response: () => Response) => {
  const sent: Sent[] = [];
  stub(globalThis, 'fetch', (async (url: unknown, init?: RequestInit) => {
    sent.push({ url: String(url), init: init ?? {}, headers: { ...(init?.headers as Record<string, string>) } });
    return response();
  }) as typeof fetch);
  return sent;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

describe('requêtes vers serviceIA', () => {
  afterEach(restoreStubs);

  it('photo + symptômes : multipart lisible, photo nommée neutre, identité retirée', async () => {
    const sent = captureFetch(() => json({ vision: { prediction: 'otomycose', confidence: 90, top3: [] } }));
    await aiService.diagnoseSeparate({
      image,
      sanitized: true,
      symptoms: 'Patient: Awa Diop\nSymptomes: Otalgie, Prurit',
      showSources: true
    });

    assert.equal(sent.length, 1);
    assert.equal(sent[0].url, `${env.AI_SERVICE_BASE_URL}/diagnose-separate`);
    // Aucun Content-Type imposé : fetch ajoute lui-même la frontière multipart.
    assert.equal(sent[0].headers['content-type'], undefined);

    // Relecture du corps tel qu'il part sur le réseau (sérialisation puis analyse multipart).
    const parsed = await new Request('http://ia.test', { method: 'POST', body: sent[0].init.body }).formData();
    const file = parsed.get('file') as File;
    assert.equal(file.name, 'otoscopie.jpg');
    assert.equal(file.type, 'image/jpeg');
    assert.deepEqual(Buffer.from(await file.arrayBuffer()), photo);
    assert.equal(parsed.get('symptoms'), 'Symptomes: Otalgie, Prurit');
    assert.equal(parsed.get('show_sources'), 'true');
  });

  it('seconde oreille : analyse d’image seule, multipart lisible, sans les symptômes', async () => {
    const sent = captureFetch(() => json({ prediction: 'tympan normal', confidence: 88, top3: [] }));
    await aiService.visionPredict({ image, sanitized: true });

    assert.equal(sent[0].url, `${env.AI_SERVICE_BASE_URL}/vision/predict`);
    assert.equal(sent[0].headers.authorization, 'Bearer jeton-ia-de-test');
    const parsed = await new Request('http://ia.test', { method: 'POST', body: sent[0].init.body }).formData();
    const file = parsed.get('file') as File;
    assert.equal(file.name, 'otoscopie.jpg');
    assert.deepEqual(Buffer.from(await file.arrayBuffer()), photo);
    assert.equal(parsed.get('symptoms'), null);
  });

  it('chaque appel porte le jeton partagé', async () => {
    const sent = captureFetch(() => json({ summary: '1. Causes probables : Otite externe.' }));
    await aiService.ragAnalyze({ symptoms: 'Otalgie' });
    await aiService.diagnoseSeparate({ image, sanitized: true, symptoms: 'Otalgie', showSources: false });
    assert.deepEqual(
      sent.map((s) => s.headers.authorization),
      ['Bearer jeton-ia-de-test', 'Bearer jeton-ia-de-test']
    );
  });

  it('sans jeton configuré (développement), aucun en-tête Authorization', async () => {
    const saved = env.AI_SERVICE_API_KEY;
    env.AI_SERVICE_API_KEY = undefined;
    try {
      const sent = captureFetch(() => json({ summary: 'x' }));
      await aiService.ragAnalyze({ symptoms: 'Otalgie' });
      assert.equal(sent[0].headers.authorization, undefined);
    } finally {
      env.AI_SERVICE_API_KEY = saved;
    }
  });

  it('jeton refusé (401) : erreur de configuration, analyse à relancer ensuite', async () => {
    captureFetch(() => json({ detail: 'Jeton d’accès au service IA manquant ou invalide.' }, 401));
    const error = await aiService.ragAnalyze({ symptoms: 'Otalgie' }).catch((e: unknown) => e);
    const described = describeAiError(error);
    assert.equal(described.code, 'AI_SERVICE_ERROR');
    assert.equal(isRetryableAiError(described.code), true);
    assert.match(described.message, /administrateur/);
  });

  it('analyse des symptômes en panne (502) : erreur temporaire, sans détail technique', async () => {
    captureFetch(() => json({ detail: 'L’analyse des symptômes est indisponible pour le moment.' }, 502));
    const described = describeAiError(await aiService.ragAnalyze({ symptoms: 'Otalgie' }).catch((e: unknown) => e));
    assert.equal(described.code, 'AI_SERVICE_ERROR');
    assert.equal(isRetryableAiError(described.code), true);
    assert.match(described.message, /temporairement indisponible/);
  });
});
