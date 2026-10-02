import assert from 'node:assert/strict';
import { after, afterEach, before, describe, it } from 'node:test';
import { restoreStubs, startTestApp, stub, type TestApp } from './helpers.js';

const { parseEnv, corsOrigins } = await import('../src/config/env.js');
const { rateLimit } = await import('../src/common/middleware/rate-limit.middleware.js');
const { runSeed } = await import('../src/common/seed.js');
const { userDao } = await import('../src/modules/users/user.dao.js');
const { medecinDao } = await import('../src/modules/medecins/medecin.dao.js');
const { clinicalReferenceDao } = await import('../src/modules/clinical-reference/clinical-reference.dao.js');

const strong = (c: string) => c.repeat(40);
const prodEnv = {
  NODE_ENV: 'production',
  AI_SERVICE_BASE_URL: 'https://ia.korai.sn',
  CORS_ORIGIN: 'https://app.korai.sn',
  JWT_ACCESS_SECRET: strong('a'),
  JWT_REFRESH_SECRET: strong('b')
};

describe('configuration de production', () => {
  it('accepte une configuration sûre', () => {
    assert.doesNotThrow(() => parseEnv(prodEnv));
  });

  it('refuse les secrets d’exemple, trop courts ou identiques', () => {
    assert.throws(() => parseEnv({ ...prodEnv, JWT_ACCESS_SECRET: 'dev_access_secret_change_me' }), /JWT_ACCESS_SECRET/);
    assert.throws(() => parseEnv({ ...prodEnv, JWT_REFRESH_SECRET: 'x'.repeat(20) }), /JWT_REFRESH_SECRET/);
    assert.throws(() => parseEnv({ ...prodEnv, JWT_REFRESH_SECRET: prodEnv.JWT_ACCESS_SECRET }), /différents/);
    assert.throws(() => parseEnv({ ...prodEnv, JWT_ACCESS_SECRET: undefined }), /JWT_ACCESS_SECRET/);
  });

  it('refuse CORS ouvert à tous en production, le permet en développement', () => {
    assert.throws(() => parseEnv({ ...prodEnv, CORS_ORIGIN: '*' }), /CORS_ORIGIN/);
    assert.doesNotThrow(() => parseEnv({ ...prodEnv, NODE_ENV: 'development', CORS_ORIGIN: '*', JWT_ACCESS_SECRET: 'dev_access_secret_x' }));
    assert.deepEqual(corsOrigins('https://a.sn, https://b.sn'), ['https://a.sn', 'https://b.sn']);
    assert.equal(corsOrigins('*'), true);
  });
});

describe('limitation de débit', () => {
  it('bloque au-delà du seuil puis se réinitialise après la fenêtre', () => {
    let t = 0;
    const limiter = rateLimit({ name: 't', windowMs: 1000, max: 2, now: () => t });
    const results: Array<number | undefined> = [];
    const req = { ip: '1.2.3.4' } as any;
    const res = { setHeader: () => undefined } as any;
    const call = () => limiter(req, res, (err?: any) => results.push(err?.statusCode));
    call();
    call();
    call();
    assert.deepEqual(results, [undefined, undefined, 429]);
    t = 1001;
    call();
    assert.equal(results[3], undefined);
  });

  describe('sur /auth/login', () => {
    let app: TestApp;
    before(async () => {
      app = await startTestApp();
    });
    after(async () => {
      await app.close();
    });
    afterEach(restoreStubs);

    it('répond 429 avec un message clair après 10 tentatives sur le même compte', async () => {
      stub(userDao, 'findByEmail', (async () => undefined) as any);
      const statuses: number[] = [];
      for (let i = 0; i < 11; i++) {
        const res = await app.request('POST', '/auth/login', { email: 'cible@korai.test', password: 'mauvais-mdp' }, '');
        statuses.push(res.status);
        if (res.status === 429) assert.match(res.body.error.message, /Trop de tentatives/);
      }
      assert.deepEqual(statuses.slice(0, 10), Array(10).fill(401));
      assert.equal(statuses[10], 429);
    });
  });
});

describe('seed de démonstration', () => {
  afterEach(restoreStubs);

  it('ne bloque jamais le démarrage et n’écrase pas le référentiel', async () => {
    const created: string[] = [];
    stub(userDao, 'count', (async () => 3) as any);
    stub(userDao, 'emailTaken', (async () => true) as any);
    stub(medecinDao, 'findByMatricule', (async () => {
      throw new Error('contrainte d’unicité'); // médecin supprimé logiquement, par exemple
    }) as any);
    stub(clinicalReferenceDao, 'createIfMissing', (async (item: { label: string }) => {
      created.push(item.label);
    }) as any);
    await assert.doesNotReject(runSeed());
    assert.ok(created.length > 20, 'chaque élément du référentiel est vérifié');
  });
});
