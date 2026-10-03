import assert from 'node:assert/strict';
import { after, afterEach, before, beforeEach, describe, it } from 'node:test';
import sharp from 'sharp';
import { allowAccess, captureAudit, makeUser, restoreStubs, signInAs, startTestApp, stub, type TestApp } from './helpers.js';

const { consultationDao } = await import('../src/modules/consultations/consultation.dao.js');
const { consultationService } = await import('../src/modules/consultations/consultation.service.js');
const { photosFromRequest, examinedEars } = await import('../src/modules/consultations/consultation.controller.js');
const { patientDao } = await import('../src/modules/patients/patient.dao.js');
const { clinicalReferenceDao } = await import('../src/modules/clinical-reference/clinical-reference.dao.js');
const { aiService } = await import('../src/modules/ai/ai.service.js');
const { imageVault } = await import('../src/modules/images/image-vault.js');

const PATIENT_ID = '00000000-0000-4000-8000-000000000001';

const jpeg = (red: number) =>
  sharp({ create: { width: 16, height: 16, channels: 3, background: { r: red, g: 80, b: 60 } } })
    .jpeg()
    .toBuffer();

const multerFile = (buffer: Buffer) =>
  ({ buffer, mimetype: 'image/jpeg', size: buffer.length, originalname: 'IMG_0042.jpg' }) as Express.Multer.File;

const vision = (prediction: string, confidence: number) => ({
  prediction,
  confidence,
  top3: [{ class: prediction, confidence }]
});

const record = (overrides: Record<string, unknown> = {}) =>
  ({
    id: 'case-1',
    patientId: 'p-1',
    createdByUserId: 'nurse-1',
    earSide: 'BOTH',
    symptomIds: [],
    symptomLabels: [],
    medicalHistoryIds: [],
    medicalHistoryLabels: [],
    touchCheckIds: [],
    touchCheckLabels: [],
    clinicalNarrative: 'Otalgie, otorrhée',
    status: 'PENDING_AI',
    urgency: 'LOW',
    createdAt: new Date(0).toISOString(),
    updatedAt: new Date(0).toISOString(),
    ...overrides
  }) as any;

describe('photos des deux tympans', () => {
  afterEach(restoreStubs);

  beforeEach(() => {
    stub(patientDao, 'findById', (async () => ({ id: 'p-1' })) as any);
    stub(clinicalReferenceDao, 'dangerScoresByIds', (async () => new Map()) as any);
    stub(consultationDao, 'create', (async () => record()) as any);
    stub(consultationDao, 'update', (async () => record({ status: 'AI_FAILED' })) as any);
    stub(consultationDao, 'findById', (async () => record({ status: 'AI_FAILED' })) as any);
    stub(aiService, 'ragAnalyze', (async () => {
      throw new Error('analyse sans photo inattendue');
    }) as any);
  });

  const submit = (images: Array<{ earSide: 'LEFT' | 'RIGHT'; file: Express.Multer.File }>) =>
    consultationService.submitDiagnosis({
      createdByUserId: 'nurse-1',
      patientId: 'p-1',
      clinicalNarrative: 'Otalgie, otorrhée',
      urgency: 'LOW',
      earSide: 'BOTH',
      images,
      imageDescription: 'Tympan droit rouge et bombé',
      showSources: true,
      requestSpecialistReview: false,
      viewerRole: 'NURSE'
    });

  it('chaque photo conservée avec son oreille ; symptômes analysés une fois, une analyse d’image par oreille', async () => {
    const stored: any[] = [];
    stub(consultationDao, 'createOtoscopicImage', (async (input: any) => {
      stored.push(input);
      return input;
    }) as any);
    let raw: any;
    stub(consultationDao, 'createAiResponse', (async (_id: string, rawJson: unknown) => {
      raw = rawJson;
      return {};
    }) as any);
    const sent: Record<string, Buffer> = {};
    stub(aiService, 'diagnoseSeparate', (async (input: any) => {
      sent.withSymptoms = input.image.buffer;
      assert.equal(input.symptoms, 'Otalgie, otorrhée');
      return { vision: vision('otite moyenne aigue', 96), rag: { summary: '1. Causes probables : Otite moyenne aiguë.' } };
    }) as any);
    stub(aiService, 'visionPredict', (async (input: any) => {
      sent.imageOnly = input.image.buffer;
      assert.equal(input.sanitized, true);
      return vision('tympan normal', 88);
    }) as any);

    await submit([
      { earSide: 'LEFT', file: multerFile(await jpeg(40)) },
      { earSide: 'RIGHT', file: multerFile(await jpeg(200)) }
    ]);

    assert.deepEqual(stored.map((image) => image.earSide), ['LEFT', 'RIGHT']);
    assert.equal(stored.filter((image) => image.description).length, 1, 'description enregistrée une seule fois');
    const keyOf = (side: string) => stored.find((image) => image.earSide === side).storageKey;
    assert.deepEqual(sent.withSymptoms, await imageVault.read(keyOf('RIGHT')), 'oreille droite analysée avec les symptômes');
    assert.deepEqual(sent.imageOnly, await imageVault.read(keyOf('LEFT')), 'oreille gauche en analyse d’image seule');
    assert.deepEqual(
      raw.ears.map((ear: any) => [ear.side, ear.vision.prediction]),
      [
        ['RIGHT', 'otite moyenne aigue'],
        ['LEFT', 'tympan normal']
      ]
    );
  });

  it('une oreille non analysée : aucun résultat enregistré, l’analyse reste à relancer', async () => {
    stub(consultationDao, 'createOtoscopicImage', (async (input: any) => input) as any);
    let saved = false;
    stub(consultationDao, 'createAiResponse', (async () => {
      saved = true;
      return {};
    }) as any);
    stub(aiService, 'diagnoseSeparate', (async () => ({ vision: vision('otomycose', 80) })) as any);
    stub(aiService, 'visionPredict', (async () => {
      throw new Error('service IA indisponible');
    }) as any);

    const result = await submit([
      { earSide: 'RIGHT', file: multerFile(await jpeg(200)) },
      { earSide: 'LEFT', file: multerFile(await jpeg(40)) }
    ]);
    assert.equal(saved, false);
    assert.equal(result.status, 'AI_FAILED');
  });

  it('relance : les deux photos conservées sont réanalysées', async () => {
    const rightKey = await imageVault.save(await jpeg(200));
    const leftKey = await imageVault.save(await jpeg(40));
    stub(consultationDao, 'findStoredImages', (async () => [
      { id: 'img-g', earSide: 'LEFT', mimeType: 'image/jpeg', storageKey: leftKey },
      { id: 'img-d', earSide: 'RIGHT', mimeType: 'image/jpeg', storageKey: rightKey }
    ]) as any);
    let raw: any;
    stub(consultationDao, 'createAiResponse', (async (_id: string, rawJson: unknown) => {
      raw = rawJson;
      return {};
    }) as any);
    stub(aiService, 'diagnoseSeparate', (async () => ({ vision: vision('otomycose', 70) })) as any);
    stub(aiService, 'visionPredict', (async () => vision('tympan normal', 90)) as any);

    await consultationService.retryDiagnosis('case-1', makeUser({ role: 'NURSE' }));
    assert.deepEqual(
      raw.ears.map((ear: any) => ear.side),
      ['RIGHT', 'LEFT']
    );
  });
});

describe('réception des photos', () => {
  const photo = multerFile(Buffer.from([0xff, 0xd8, 0xff]));

  it('une photo par oreille : droite et gauche, consultation des deux oreilles', () => {
    const photos = photosFromRequest({ fileLeft: [photo], fileRight: [photo] }, 'RIGHT');
    assert.deepEqual(
      photos.map((p) => p.earSide),
      ['RIGHT', 'LEFT']
    );
    assert.equal(examinedEars('RIGHT', photos), 'BOTH');
  });

  it('`file` seul : l’oreille déclarée (parcours patient, envois d’une version précédente)', () => {
    const photos = photosFromRequest({ file: [photo] }, 'LEFT');
    assert.deepEqual(
      photos.map((p) => p.earSide),
      ['LEFT']
    );
    assert.equal(examinedEars('LEFT', photos), 'LEFT');
  });

  it('deux oreilles examinées, une seule photographiée : reste « les deux »', () => {
    assert.equal(examinedEars('BOTH', photosFromRequest({ fileLeft: [photo] }, 'BOTH')), 'BOTH');
  });

  it('`file` et une photo par oreille ensemble : refusé', () => {
    assert.throws(() => photosFromRequest({ file: [photo], fileLeft: [photo] }, 'LEFT'), /une photo par oreille/);
  });
});

describe('POST /cases/diagnose avec deux photos', () => {
  let app: TestApp;
  let received: any;

  before(async () => {
    app = await startTestApp();
  });
  after(async () => {
    await app.close();
  });
  beforeEach(async () => {
    received = undefined;
    await allowAccess(true);
    await captureAudit();
    await signInAs(makeUser({ id: 'nurse-1', role: 'NURSE', facilityId: 'fac-1' }));
    stub(patientDao, 'findById', (async () => ({
      id: PATIENT_ID,
      createdByUserId: 'nurse-1',
      consentForAi: true,
      consentForTeleExpertise: true,
      facilityId: 'fac-1',
      isValidated: true
    })) as any);
    stub(consultationService, 'submitDiagnosis', (async (input: any) => {
      received = input;
      return { id: 'case-1', patientId: PATIENT_ID, status: 'AI_COMPLETED' };
    }) as any);
  });
  afterEach(restoreStubs);

  const send = async (files: Record<string, Buffer>, earSide = 'RIGHT') => {
    const form = new FormData();
    form.append('patientId', PATIENT_ID);
    form.append('symptoms', 'Otalgie, otorrhée');
    form.append('earSide', earSide);
    for (const [field, bytes] of Object.entries(files)) {
      form.append(field, new Blob([new Uint8Array(bytes)], { type: 'image/jpeg' }), `${field}.jpg`);
    }
    const res = await fetch(`${app.url}/cases/diagnose`, {
      method: 'POST',
      headers: { authorization: 'Bearer jeton-de-test' },
      body: form
    });
    return { status: res.status, body: await res.json() };
  };

  it('fileRight et fileLeft arrivent au service, consultation des deux oreilles', async () => {
    const res = await send({ fileRight: await jpeg(200), fileLeft: await jpeg(40) });
    assert.equal(res.status, 201);
    assert.deepEqual(
      received.images.map((photo: any) => photo.earSide),
      ['RIGHT', 'LEFT']
    );
    assert.equal(received.earSide, 'BOTH');
  });

  it('trois photos ou un champ inconnu : 400 avec un message clair, pas une erreur interne', async () => {
    const photo = await jpeg(120);
    for (const files of [{ fileRight: photo, fileLeft: photo, file: photo }, { photoEnPlus: photo }]) {
      const res = await send(files);
      assert.equal(res.status, 400);
      assert.match(res.body.error.message, /Une photo par oreille au plus/);
    }
    assert.equal(received, undefined);
  });

  it('`file` mêlé aux photos par oreille : 400 avec un message clair', async () => {
    const res = await send({ file: await jpeg(200), fileLeft: await jpeg(40) });
    assert.equal(res.status, 400);
    assert.match(res.body.error.message, /une photo par oreille/);
    assert.equal(received, undefined);
  });
});
