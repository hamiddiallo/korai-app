import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import './helpers.js';

const { extractAiFieldsFromRaw, firstProbableCause } = await import('../src/modules/ai/ai.service.js');

/** Réponse réelle de serviceIA /diagnose-separate (confiance du modèle de vision en %). */
const separate = (confidence: number, summary = SUMMARY) => ({
  case_id: 'A1B2C3D4',
  timestamp: '2026-10-02T23:48:51',
  vision: {
    prediction: 'otite moyenne aigue',
    confidence,
    top3: [
      { class: 'otite moyenne aigue', confidence },
      { class: 'perforation tympanique', confidence: 2.1 },
      { class: 'tympan normal', confidence: 0.6 }
    ],
    timestamp: '2026-10-02T23:48:51'
  },
  rag: {
    summary,
    sources: [{ source: 'Guide_ORL_2023.pdf', page: 12, content: 'Otite moyenne aiguë…' }],
    timestamp: '2026-10-02T23:48:51'
  },
  requires_expert_validation: true
});

const SUMMARY = [
  '1. Causes probables',
  'Otite externe diffuse ou localisée (bactérienne, fongique), otite moyenne chronique avec perforation tympanique.',
  '',
  '2. Signes associés',
  'Otalgie, otorrhée purulente.',
  '',
  '3. Conduite à tenir',
  'Examen otoscopique, antibiothérapie locale.'
].join('\n');

describe('lecture des réponses de serviceIA', () => {
  it('photo : diagnostic du modèle de vision, confiance en pourcentage ramenée sur 1', () => {
    const extract = extractAiFieldsFromRaw(separate(96.8), { hadOtoscopicImage: true });
    assert.equal(extract.likelyDiagnosis, 'Otite moyenne aiguë');
    assert.equal(extract.confidenceLabel, 'HIGH');
    assert.equal(
      extract.imageOpinion,
      'Otite moyenne aiguë (97 %). Autres possibilités : Perforation tympanique (2 %), Tympan normal (1 %).'
    );
    assert.equal(extract.ragOpinion, SUMMARY);
    assert.deepEqual(extract.sources, ['Guide_ORL_2023.pdf · p. 12']);
    assert.deepEqual(extract.warnings, [], 'image et symptômes reconnus');
  });

  it('analyse des symptômes en panne : la photo reste analysée, avertissement clair', () => {
    const partial = { ...separate(96.8), rag: null, rag_error: 'L’analyse des symptômes est indisponible pour le moment.' };
    const extract = extractAiFieldsFromRaw(partial, { hadOtoscopicImage: true });
    assert.equal(extract.likelyDiagnosis, 'Otite moyenne aiguë');
    assert.equal(extract.confidenceLabel, 'HIGH');
    assert.equal(extract.ragOpinion, undefined);
    assert.deepEqual(extract.warnings, [
      'Avis IA sur les symptômes indisponible (service d’analyse en panne) : seule la photo a été analysée.'
    ]);
  });

  it('photo peu reconnue (24 %) : confiance faible et avertissement', () => {
    const extract = extractAiFieldsFromRaw(separate(24.16), { hadOtoscopicImage: true });
    assert.equal(extract.confidenceLabel, 'LOW');
    assert.ok(extract.warnings.some((w) => /Confiance IA faible/.test(w)));
  });

  it('symptômes seuls (/rag/analyze) : première cause probable, pas tout le texte', () => {
    const extract = extractAiFieldsFromRaw({ summary: SUMMARY, sources: null, timestamp: 'x' });
    assert.equal(extract.likelyDiagnosis, 'Otite externe diffuse ou localisée (bactérienne, fongique)');
    assert.equal(extract.ragOpinion, SUMMARY);
    assert.equal(extract.confidenceLabel, 'UNKNOWN');
  });

  it('base documentaire sans réponse : pas de faux diagnostic', () => {
    const extract = extractAiFieldsFromRaw({ summary: '1. Causes probables : Non documenté dans la base ORL.' });
    assert.equal(extract.likelyDiagnosis, undefined);
  });

  it('variantes de mise en forme de la section « Causes probables »', () => {
    assert.equal(firstProbableCause('Causes probables : Otomycose ; otite externe.'), 'Otomycose');
    assert.equal(firstProbableCause('1) Causes probables\n- bouchon de cérumen, corps étranger'), 'Bouchon de cérumen');
    assert.equal(firstProbableCause('Texte libre sans section'), undefined);
  });

  it('réponses réelles de Ministral : nom de la pathologie sans son explication', () => {
    assert.equal(
      firstProbableCause(
        '1. Causes probables :\n   Otite moyenne aiguë (OMA) : inflammation aiguë de la caisse du tympan, secondaire à une rhinopharyngite.'
      ),
      'Otite moyenne aiguë (OMA)'
    );
    assert.equal(
      firstProbableCause(
        '1. Causes probables :\n   - Otite externe maligne (ou otite nécrosante) : liée à l’otorrhée persistante et au diabète.\n\n2. Signes associés :'
      ),
      'Otite externe maligne (ou otite nécrosante)'
    );
    // « non documenté » dans l'explication d'une cause n'annule pas le diagnostic.
    assert.equal(
      firstProbableCause(
        '1. Causes probables :\n   - Otite externe diffuse : prurit, baignades.\n   - Otite moyenne : moins probable (non documenté dans le contexte).\n2. Signes associés :'
      ),
      'Otite externe diffuse'
    );
  });

  it('l’ancien format (image_ai / rag_ai) reste compris', () => {
    const extract = extractAiFieldsFromRaw(
      { image_ai: { diagnosis: 'Otite externe', confidence: 0.5 }, rag_ai: { answer: 'Analyse' } },
      { hadOtoscopicImage: true }
    );
    assert.equal(extract.likelyDiagnosis, 'Otite externe');
    assert.equal(extract.confidenceLabel, 'MEDIUM');
    assert.equal(extract.ragOpinion, 'Analyse');
  });
});
