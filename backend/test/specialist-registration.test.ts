import assert from 'node:assert/strict';
import { after, afterEach, before, describe, it } from 'node:test';
import jwt from 'jsonwebtoken';
import { makeUser, restoreStubs, signInAs, startTestApp, stub, type TestApp } from './helpers.js';

const { userDao } = await import('../src/modules/users/user.dao.js');
const { medecinDao } = await import('../src/modules/medecins/medecin.dao.js');

const userRecord = (overrides: Record<string, unknown> = {}) => ({
  id: 'spec-1',
  fullName: 'Awa Ndiaye',
  email: 'awa@korai.test',
  role: 'SPECIALIST',
  accountStatus: 'PENDING',
  passwordHash: '$2a$10$abcdefghijklmnopqrstuv',
  matricule: 'ORL002',
  rejectionReason: null,
  createdAt: new Date(0).toISOString(),
  ...overrides
});

describe('inscription spécialiste validée par un administrateur', () => {
  let app: TestApp;
  before(async () => {
    app = await startTestApp();
  });
  after(async () => {
    await app.close();
  });
  afterEach(restoreStubs);

  it('crée un compte en attente, sans jeton', async () => {
    let created: any;
    stub(medecinDao, 'findByMatricule', (async () => ({ id: 'm-2', matricule: 'ORL002' })) as any);
    stub(userDao, 'findSpecialistByMatricule', (async () => undefined) as any);
    stub(userDao, 'findByEmail', (async () => undefined) as any);
    stub(userDao, 'create', (async (input: any) => {
      created = input;
      return userRecord({ ...input, id: 'spec-1' });
    }) as any);

    const res = await app.request(
      'POST',
      '/auth/register/specialist',
      { fullName: 'Awa Ndiaye', email: 'awa@korai.test', password: 'MotDePasse123', matricule: 'ORL002' },
      ''
    );
    assert.equal(res.status, 201);
    assert.equal(res.body.pending, true);
    assert.equal(res.body.accessToken, undefined);
    assert.equal(created.accountStatus, 'PENDING');
    assert.match(res.body.message, /administrateur/);
  });

  it('la connexion d’un spécialiste en attente explique qui doit valider', async () => {
    const bcrypt = (await import('bcryptjs')).default;
    const hash = await bcrypt.hash('MotDePasse123', 4);
    stub(userDao, 'findByEmail', (async () => userRecord({ passwordHash: hash })) as any);
    const res = await app.request('POST', '/auth/login', { email: 'awa@korai.test', password: 'MotDePasse123' }, '');
    assert.equal(res.status, 403);
    assert.equal(res.body.error.code, 'ACCOUNT_PENDING');
    assert.match(res.body.error.message, /administrateur/);
  });

  it('l’administrateur active ou refuse un compte en attente', async () => {
    await signInAs(makeUser({ role: 'ADMIN' }));
    const statuses: string[] = [];
    stub(userDao, 'findById', (async () => userRecord()) as any);
    stub(userDao, 'setAccountStatus', (async (_id: string, status: string, reason: string | null) => {
      statuses.push(`${status}:${reason ?? ''}`);
      return userRecord({ accountStatus: status, rejectionReason: reason });
    }) as any);

    const ok = await app.request('POST', '/admin/users/spec-1/approve');
    assert.equal(ok.status, 200);
    assert.equal(ok.body.user.accountStatus, 'ACTIVE');
    assert.equal(ok.body.user.passwordHash, undefined, 'hash jamais exposé');

    const no = await app.request('POST', '/admin/users/spec-1/reject', { reason: 'Identité non vérifiée' });
    assert.equal(no.status, 200);
    assert.deepEqual(statuses, ['ACTIVE:', 'REJECTED:Identité non vérifiée']);
  });

  it('refuse de valider un compte déjà actif, et réserve l’action aux administrateurs', async () => {
    await signInAs(makeUser({ role: 'ADMIN' }));
    stub(userDao, 'findById', (async () => userRecord({ accountStatus: 'ACTIVE' })) as any);
    assert.equal((await app.request('POST', '/admin/users/spec-1/approve')).status, 409);

    restoreStubs();
    await signInAs(makeUser({ role: 'SPECIALIST' }));
    assert.equal((await app.request('POST', '/admin/users/spec-1/approve')).status, 403);
  });

  it('un jeton valide ne sert plus à rien si le compte n’est plus actif', async () => {
    stub(userDao, 'findById', (async () => userRecord({ accountStatus: 'REJECTED' })) as any);
    const token = jwt.sign({ sub: 'spec-1', role: 'SPECIALIST' }, process.env.JWT_ACCESS_SECRET!, { expiresIn: '5m' });
    const res = await app.request('GET', '/auth/me', undefined, token);
    assert.equal(res.status, 401);
  });
});
