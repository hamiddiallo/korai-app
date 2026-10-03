import assert from 'node:assert/strict';
import { readFile, readdir, writeFile, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { after, afterEach, before, beforeEach, describe, it } from 'node:test';
import sharp from 'sharp';
import { allowAccess, captureAudit, makeUser, restoreStubs, signInAs, startTestApp, stub, type TestApp } from './helpers.js';

const { imageVault, encryptImage, looksLikeImage } = await import('../src/modules/images/image-vault.js');
const { env } = await import('../src/config/env.js');
const { consultationDao } = await import('../src/modules/consultations/consultation.dao.js');
const { consultationService } = await import('../src/modules/consultations/consultation.service.js');
const { patientDao } = await import('../src/modules/patients/patient.dao.js');
const { clinicalReferenceDao } = await import('../src/modules/clinical-reference/clinical-reference.dao.js');
const { aiService } = await import('../src/modules/ai/ai.service.js');
const { toLegacyOrlCase } = await import('../src/modules/consultations/consultation.types.js');

/** Petite photo JPEG avec des métadonnées EXIF (comme un téléphone). */
const photoWithExif = () =>
  sharp({ create: { width: 16, height: 16, channels: 3, background: { r: 200, g: 80, b: 60 } } })
    .jpeg()
    .withExif({ IFD0: { Make: 'TelephoneDuSoignant', Artist: 'Awa Diop' } })
    .toBuffer();

const record = (overrides: Record<string, unknown> = {}) =>
  ({
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
    clinicalNarrative: 'Otalgie gauche',
    status: 'PENDING_AI',
    urgency: 'LOW',
    createdAt: new Date(0).toISOString(),
    updatedAt: new Date(0).toISOString(),
    ...overrides
  }) as any;

describe('coffre des photos', () => {
  it('la photo est chiffrée sur le disque et se relit à l’identique', async () => {
    const photo = await photoWithExif();
    const key = await imageVault.save(photo);
    const onDisk = await readFile(path.resolve(env.IMAGE_STORAGE_DIR, `${key}.enc`));
    assert.ok(!onDisk.includes(photo.subarray(0, 64)), 'aucun octet de la photo en clair');
    assert.ok(!onDisk.includes(Buffer.from('Awa Diop')));
    assert.deepEqual(await imageVault.read(key), photo);
  });

  it('un fichier modifié ou échangé avec un autre ne se déchiffre pas', async () => {
    const a = await imageVault.save(Buffer.from('photo A'));
    const b = await imageVault.save(Buffer.from('photo B'));
    const fileA = path.resolve(env.IMAGE_STORAGE_DIR, `${a}.enc`);
    const fileB = path.resolve(env.IMAGE_STORAGE_DIR, `${b}.enc`);

    await copyFile(fileA, fileB); // photo A rangée sous le nom de B
    await assert.rejects(imageVault.read(b), /illisible/);

    const tampered = await readFile(fileA);
    tampered[tampered.length - 1] ^= 0xff;
    await writeFile(fileA, tampered);
    await assert.rejects(imageVault.read(a), /illisible/);
  });

  it('refuse un identifiant qui sortirait du dossier, ou une mauvaise clé', async () => {
    await assert.rejects(imageVault.read('../../.env'), /invalide/);
    const key = '00000000-0000-4000-8000-000000000001';
    assert.throws(
      () => encryptImage(Buffer.from('x'), key, Buffer.alloc(16)),
      /Invalid key length/,
      'clé de 16 octets refusée par AES-256'
    );
  });

  it('reconnaît une vraie photo à sa signature, pas à son extension', async () => {
    assert.equal(looksLikeImage(await photoWithExif(), 'image/jpeg'), true);
    const png = await sharp({ create: { width: 2, height: 2, channels: 3, background: '#fff' } }).png().toBuffer();
    assert.equal(looksLikeImage(png, 'image/png'), true);
    assert.equal(looksLikeImage(Buffer.from('<script>alert(1)</script>'), 'image/jpeg'), false);
    assert.equal(looksLikeImage(png, 'image/jpeg'), false);
  });
});

describe('photo d’une consultation', () => {
  afterEach(restoreStubs);

  const baseInput = (image: Express.Multer.File) => ({
    createdByUserId: 'nurse-1',
    patientId: 'p-1',
    clinicalNarrative: 'Otalgie gauche',
    urgency: 'LOW' as const,
    earSide: 'LEFT' as const,
    images: [{ earSide: 'LEFT' as const, file: image }],
    showSources: true,
    requestSpecialistReview: false,
    viewerRole: 'NURSE' as const
  });

  const multerFile = (buffer: Buffer, mimetype = 'image/jpeg') =>
    ({ buffer, mimetype, size: buffer.length, originalname: 'IMG_Awa_Diop.jpg' }) as Express.Multer.File;

  beforeEach(() => {
    stub(patientDao, 'findById', (async () => ({ id: 'p-1' })) as any);
    stub(clinicalReferenceDao, 'dangerScoresByIds', (async () => new Map()) as any);
    stub(consultationDao, 'create', (async () => record()) as any);
    stub(consultationDao, 'update', (async () => record({ status: 'AI_FAILED' })) as any);
    stub(consultationDao, 'findById', (async () => record({ status: 'AI_FAILED' })) as any);
  });

  it('conservée chiffrée, sans métadonnées, avant l’IA — même si l’IA échoue', async () => {
    const images: any[] = [];
    stub(consultationDao, 'createOtoscopicImage', (async (input: any) => {
      images.push(input);
      return input;
    }) as any);
    let sentToAi: Buffer | undefined;
    stub(aiService, 'diagnoseSeparate', (async (input: any) => {
      assert.equal(input.sanitized, true);
      sentToAi = input.image.buffer;
      throw new Error('service IA indisponible');
    }) as any);

    const photo = await photoWithExif();
    await consultationService.submitDiagnosis(baseInput(multerFile(photo)));

    assert.equal(images.length, 1);
    assert.match(images[0].storageKey, /^[0-9a-f-]{36}$/);
    assert.equal(images[0].fileName, 'otoscopie.jpg', 'nom de fichier neutre');
    const stored = await imageVault.read(images[0].storageKey);
    assert.deepEqual(stored, sentToAi, 'l’IA reçoit exactement la photo conservée');
    const metadata = await sharp(stored).metadata();
    assert.equal(metadata.exif, undefined, 'métadonnées EXIF retirées');
  });

  it('un faux fichier image est refusé avant tout enregistrement', async () => {
    let created = false;
    stub(consultationDao, 'create', (async () => {
      created = true;
      return record();
    }) as any);
    await assert.rejects(
      consultationService.submitDiagnosis(baseInput(multerFile(Buffer.from('ceci n’est pas une photo')))),
      /pas une photo JPEG, PNG ou WebP/
    );
    assert.equal(created, false);
  });

  it('une analyse relancée repart de la photo conservée', async () => {
    const photo = await sharp(await photoWithExif()).jpeg().toBuffer();
    const storageKey = await imageVault.save(photo);
    stub(consultationDao, 'findStoredImages', (async () => [
      { id: 'img-1', earSide: 'LEFT', mimeType: 'image/jpeg', storageKey }
    ]) as any);
    stub(consultationDao, 'createAiResponse', (async () => ({})) as any);
    let withImage: Buffer | undefined;
    let textOnly = false;
    stub(aiService, 'diagnoseSeparate', (async (input: any) => {
      withImage = input.image.buffer;
      return { likely_diagnosis: 'Otite externe' };
    }) as any);
    stub(aiService, 'ragAnalyze', (async () => {
      textOnly = true;
      return {};
    }) as any);

    await consultationService.retryDiagnosis('case-1', makeUser({ role: 'NURSE' }));
    assert.deepEqual(withImage, photo);
    assert.equal(textOnly, false);
  });

  it('la consultation n’expose que les photos conservées, par une adresse contrôlée', () => {
    const c = toLegacyOrlCase(
      record({
        otoscopicImages: [
          { id: 'img-1', earSide: 'LEFT', mimeType: 'image/jpeg', stored: true, createdAt: '2026-10-02T10:00:00Z' },
          { id: 'img-2', earSide: 'LEFT', mimeType: 'text/plain', stored: false, createdAt: '2026-10-02T10:00:00Z' },
          {
            id: 'img-3',
            earSide: 'LEFT',
            mimeType: 'image/jpeg',
            stored: true,
            deletedAt: '2026-10-02T11:00:00Z',
            createdAt: '2026-10-02T10:00:00Z'
          }
        ]
      })
    );
    assert.deepEqual(
      c.images.map((i) => i.url),
      ['/cases/case-1/images/img-1']
    );
    assert.ok(!JSON.stringify(c).includes('storageKey'));
  });
});

describe('GET /cases/:id/images/:imageId', () => {
  let app: TestApp;
  let photo: Buffer;
  let storageKey: string;
  let audits: any[];

  before(async () => {
    app = await startTestApp();
    photo = await sharp(await photoWithExif()).jpeg().toBuffer();
    storageKey = await imageVault.save(photo);
  });
  after(async () => {
    await app.close();
  });
  beforeEach(async () => {
    audits = await captureAudit();
    await signInAs(makeUser({ id: 'orl-1', role: 'SPECIALIST' }));
    stub(consultationDao, 'findById', (async () => record()) as any);
  });
  afterEach(restoreStubs);

  const get = (p: string) => fetch(`${app.url}${p}`, { headers: { authorization: 'Bearer jeton-de-test' } });

  it('renvoie la photo déchiffrée, jamais mise en cache, et trace la consultation', async () => {
    await allowAccess(true);
    stub(consultationDao, 'findStoredImage', (async () => ({ id: 'img-1', mimeType: 'image/jpeg', storageKey })) as any);
    const res = await get('/cases/case-1/images/img-1');
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-type'), 'image/jpeg');
    assert.equal(res.headers.get('cache-control'), 'private, no-store');
    assert.deepEqual(Buffer.from(await res.arrayBuffer()), photo);
    await new Promise((r) => setImmediate(r));
    assert.deepEqual(
      audits.map((a) => [a.action, a.actorUserId, a.patientId]),
      [['IMAGE_VIEWED', 'orl-1', 'p-1']]
    );
  });

  it('refusée hors du périmètre d’accès', async () => {
    await allowAccess(false);
    let read = false;
    stub(consultationDao, 'findStoredImage', (async () => {
      read = true;
      return null;
    }) as any);
    assert.equal((await get('/cases/case-1/images/img-1')).status, 403);
    assert.equal(read, false);
  });

  it('photo absente ou d’une autre consultation : introuvable', async () => {
    await allowAccess(true);
    stub(consultationDao, 'findStoredImage', (async () => null) as any);
    assert.equal((await get('/cases/case-1/images/autre')).status, 404);
  });

  it('aucun fichier en clair dans le dossier des photos', async () => {
    const files = await readdir(path.resolve(env.IMAGE_STORAGE_DIR));
    assert.ok(files.length > 0);
    assert.ok(files.every((f) => f.endsWith('.enc')));
  });
});
