import { z } from 'zod';

/**
 * Booléen reçu en JSON ou en multipart/form-data (où tout est texte).
 * `z.coerce.boolean()` est à proscrire : il convertit la chaîne "false" en
 * `true` (toute chaîne non vide est « vraie »).
 */
export const booleanish = (defaultValue: boolean) =>
  z.preprocess((value) => {
    if (value === undefined || value === null || value === '') return defaultValue;
    if (typeof value === 'string') {
      const normalized = value.trim().toLowerCase();
      if (normalized === 'true' || normalized === '1') return true;
      if (normalized === 'false' || normalized === '0') return false;
    }
    return value; // valeur inattendue : refusée par z.boolean()
  }, z.boolean());
