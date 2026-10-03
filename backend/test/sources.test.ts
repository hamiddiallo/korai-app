import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { cleanSourceLabel, collectSources } from '../src/common/utils/sources.js';

describe('libellés des sources du service IA', () => {
  it('retire le chemin Windows de la base indexée (nom de l’auteur compris)', () => {
    assert.deepEqual(
      collectSources({
        sources: [
          { source: 'C:\\Users\\DonutGiveUp\\Documents\\KORAI\\documents_orl\\EMC-ORL.pdf', page: 602 },
          'C:\\Users\\DonutGiveUp\\Documents\\KORAI\\documents_orl\\Otoscopie.pdf · p. 37'
        ]
      }),
      ['EMC-ORL.pdf · p. 602', 'Otoscopie.pdf · p. 37']
    );
  });

  it('chemins Linux ou macOS également', () => {
    assert.equal(cleanSourceLabel('/data/documents_orl/Guide.pdf · p. 3'), 'Guide.pdf · p. 3');
  });

  it('URL, titres ordinaires et libellés déjà propres inchangés', () => {
    assert.equal(cleanSourceLabel('https://has-sante.fr/otites.pdf'), 'https://has-sante.fr/otites.pdf');
    assert.equal(cleanSourceLabel('ORL adulte/enfant · p. 12'), 'ORL adulte/enfant · p. 12');
    assert.equal(cleanSourceLabel('EMC-ORL.pdf · p. 97'), 'EMC-ORL.pdf · p. 97');
  });
});
