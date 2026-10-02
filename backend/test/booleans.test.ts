import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import './helpers.js';

const { booleanish } = await import('../src/common/utils/zod.js');
const { createConsultationSchema } = await import('../src/modules/consultations/consultation.schemas.js');

const baseConsultation = {
  patientId: '11111111-1111-4111-8111-111111111111',
  symptoms: 'Otalgie droite depuis trois jours'
};

describe('booléens reçus en texte (multipart)', () => {
  it('"false" reste faux — plus de télé-expertise demandée par erreur', () => {
    const parsed = createConsultationSchema.parse({ ...baseConsultation, requestSpecialistReview: 'false' });
    assert.equal(parsed.requestSpecialistReview, false);
  });

  it('"true", true, "1" sont vrais ; "0" est faux', () => {
    assert.equal(createConsultationSchema.parse({ ...baseConsultation, requestSpecialistReview: 'true' }).requestSpecialistReview, true);
    assert.equal(createConsultationSchema.parse({ ...baseConsultation, requestSpecialistReview: true }).requestSpecialistReview, true);
    assert.equal(booleanish(false).parse('1'), true);
    assert.equal(booleanish(true).parse('0'), false);
  });

  it('valeur absente ou vide : valeur par défaut', () => {
    const parsed = createConsultationSchema.parse(baseConsultation);
    assert.equal(parsed.requestSpecialistReview, false);
    assert.equal(parsed.showSources, true);
    assert.equal(booleanish(false).parse(''), false);
  });

  it('valeur inattendue refusée', () => {
    assert.equal(booleanish(false).safeParse('oui').success, false);
    assert.equal(createConsultationSchema.safeParse({ ...baseConsultation, requestSpecialistReview: 'peut-être' }).success, false);
  });
});
