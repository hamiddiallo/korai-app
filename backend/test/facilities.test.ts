import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, afterEach, before, beforeEach, describe, it } from 'node:test';
import { captureAudit, makeUser, restoreStubs, signInAs, startTestApp, stub, type TestApp } from './helpers.js';

const { facilityDao, normalizeFacilityName } = await import('../src/modules/facilities/facility.dao.js');
const { userDao } = await import('../src/modules/users/user.dao.js');
const { medecinDao } = await import('../src/modules/medecins/medecin.dao.js');

describe('noms d’établissement', () => {
  it('accents, casse et espaces ne créent pas de doublon', () => {
    assert.equal(normalizeFacilityName('  Hôpital   Fann '), 'hopital fann');
    assert.equal(normalizeFacilityName('HOPITAL FANN'), 'hopital fann');
    assert.equal(normalizeFacilityName('Poste de santé de Yoff'), 'poste de sante de yoff');
  });

  it('même normalisation que la migration SQL (données existantes)', () => {
    const sql = readFileSync(
      new URL('../prisma/migrations/20260928090000_facilities_consent_audit/migration.sql', import.meta.url),
      'utf8'
    );
    const [, from, to] = sql.match(/translate\(lower\(trim\("healthFacility"\)\),\s*'([^']+)',\s*'([^']+)'\)/)!;
    assert.equal([...from!].length, [...to!].length);
    [...from!].forEach((accented, i) => {
      assert.equal(normalizeFacilityName(accented), [...to!][i], accented);
    });
  });
});

describe('établissement des soignants', () => {
  let app: TestApp;

  before(async () => {
    app = await startTestApp();
  });
  after(async () => {
    await app.close();
  });
  beforeEach(async () => {
    await captureAudit();
  });
  afterEach(restoreStubs);

  it('inscription d’un soignant : il rejoint l’établissement déclaré', async () => {
    stub(userDao, 'findByEmail', (async () => undefined) as any);
    stub(medecinDao, 'findByMatricule', (async () => ({ matricule: 'ORL001' })) as any);
    stub(userDao, 'findSpecialistByMatricule', (async () => undefined) as any);
    stub(facilityDao, 'findOrCreate', (async (name: string) => ({ id: 'fac-fann', name: name.trim() })) as any);
    let created: any;
    stub(userDao, 'create', (async (input: any) => {
      created = input;
      return { id: 'n-1', ...input };
    }) as any);

    const res = await app.request(
      'POST',
      '/auth/register/nurse',
      {
        fullName: 'Kevin',
        email: 'kevin@korai.test',
        password: 'MotDePasse123',
        healthFacility: ' Fann ',
        supervisorMatricule: 'ORL001'
      },
      ''
    );
    assert.equal(res.status, 201);
    assert.equal(created.facilityId, 'fac-fann');
    assert.equal(created.healthFacility, 'Fann');
    assert.equal(created.accountStatus, 'PENDING');
  });

  it('un soignant ne peut pas changer lui-même d’établissement', async () => {
    const nurse = makeUser({ id: 'n-1', role: 'NURSE', healthFacility: 'Fann', facilityId: 'fac-fann' });
    await signInAs(nurse);
    stub(userDao, 'findById', (async () => ({ ...nurse, passwordHash: 'x' })) as any);
    stub(userDao, 'update', (async (_id: string, patch: any) => ({ ...nurse, ...patch })) as any);

    const moved = await app.request('PATCH', '/auth/me', { healthFacility: 'Hôpital Principal' });
    assert.equal(moved.status, 403);
    assert.equal(moved.body.error.code, 'FACILITY_CHANGE_FORBIDDEN');

    const same = await app.request('PATCH', '/auth/me', { healthFacility: 'FANN', phone: '770000000' });
    assert.equal(same.status, 200);
  });

  it('liste publique pour l’inscription : noms seulement', async () => {
    stub(facilityDao, 'list', (async () => [{ id: 'fac-fann', name: 'Fann' }]) as any);
    const res = await app.request('GET', '/facilities', undefined, '');
    assert.equal(res.status, 200);
    assert.deepEqual(res.body.facilities, [{ id: 'fac-fann', name: 'Fann' }]);
  });
});
