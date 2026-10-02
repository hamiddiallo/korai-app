import { UrgencyLevel } from '@prisma/client';
import { clinicalReferenceDao } from '../clinical-reference/clinical-reference.dao.js';

/**
 * Calcule le niveau d'urgence d'une demande à partir des scores de danger
 * (0–3) du référentiel clinique, répartis en deux familles :
 *   - signes de l'épisode : symptômes cochés + vérifications au toucher dont
 *     le résultat est anormal ;
 *   - terrain : antécédents cochés.
 *
 * Formule (explicable) :
 *   S = max(scores des signes)          — le signe le plus grave
 *   A = max(scores des antécédents)     — le terrain le plus fragile
 *   synergie  = (S ≥ 2 ET A ≥ 2)        — signe préoccupant sur terrain fragile
 *   cumul     = (≥ 2 signes de score ≥ 2)
 *   combiné   = min(max(S, min(A, 2)) + synergie + cumul, 4)
 *
 * Un antécédent seul plafonne à « moyen » (min(A, 2)) : il rend un signe plus
 * inquiétant mais ne constitue pas une urgence à lui seul.
 *
 * Seuils : combiné ≤ 1 → LOW · = 2 → MEDIUM · ≥ 3 → HIGH
 *
 * ⚠️ Recopié dans `frontend/lib/core/domain/clinical_urgency.dart` (aperçu et
 * consultations hors ligne). Les deux sont vérifiés sur les mêmes cas :
 * `backend/test/fixtures/urgency-cases.json`.
 */
export const computeUrgency = (signScores: number[], historyScores: number[]): UrgencyLevel => {
  const safe = (values: number[]) =>
    values.map((v) => (Number.isFinite(v) ? Math.min(3, Math.max(0, v)) : 0));

  const signs = safe(signScores);
  const histories = safe(historyScores);

  const s = signs.length ? Math.max(...signs) : 0;
  const a = histories.length ? Math.max(...histories) : 0;
  const highSignCount = signs.filter((v) => v >= 2).length;

  const synergy = s >= 2 && a >= 2 ? 1 : 0;
  const accumulation = highSignCount >= 2 ? 1 : 0;

  const combined = Math.min(Math.max(s, Math.min(a, 2)) + synergy + accumulation, 4);

  if (combined >= 3) return UrgencyLevel.HIGH;
  if (combined === 2) return UrgencyLevel.MEDIUM;
  return UrgencyLevel.LOW;
};

/**
 * Une vérification au toucher ne compte comme signe que si son résultat est
 * anormal (« Anormal — léger / modéré / sévère ») : « Normal (négatif) » et
 * « Non réalisé » n'apportent rien à l'urgence.
 */
export const isAbnormalTouchFinding = (observation: string | null | undefined): boolean =>
  typeof observation === 'string' && /^\s*anormal/i.test(observation);

/**
 * Niveau d'urgence d'une sélection clinique, à partir des scores de danger en
 * base (le serveur fait autorité ; la valeur envoyée par l'app est ignorée).
 */
export const resolveUrgency = async (selection: {
  symptomIds?: string[];
  medicalHistoryIds?: string[];
  touchCheckIds?: string[];
  touchObservations?: Record<string, string>;
}): Promise<UrgencyLevel> => {
  const symptomIds = selection.symptomIds ?? [];
  const historyIds = selection.medicalHistoryIds ?? [];
  const abnormalTouchIds = (selection.touchCheckIds ?? []).filter((id) =>
    isAbnormalTouchFinding(selection.touchObservations?.[id])
  );

  const scores = await clinicalReferenceDao.dangerScoresByIds([
    ...new Set([...symptomIds, ...historyIds, ...abnormalTouchIds])
  ]);
  const scoreOf = (id: string) => scores.get(id) ?? 0;

  return computeUrgency(
    [...symptomIds, ...abnormalTouchIds].map(scoreOf),
    historyIds.map(scoreOf)
  );
};
