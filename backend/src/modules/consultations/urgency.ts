import { UrgencyLevel } from '@prisma/client';

/**
 * Calcule le niveau d'urgence d'une demande à partir des scores de danger
 * (0–3) des symptômes et antécédents sélectionnés.
 *
 * Formule (explicable) :
 *   S = max(scores symptômes)        — le symptôme le plus grave
 *   A = max(scores antécédents)      — l'antécédent le plus grave
 *   synergie  = (S ≥ 2 ET A ≥ 2)     — signe préoccupant sur terrain fragile
 *   cumul     = (≥ 2 symptômes de score ≥ 2)
 *   combiné   = min(max(S, A) + synergie + cumul, 4)
 *
 * Seuils : combiné ≤ 1 → LOW · = 2 → MEDIUM · ≥ 3 → HIGH
 */
export const computeUrgency = (
  symptomScores: number[],
  historyScores: number[]
): UrgencyLevel => {
  const safe = (values: number[]) =>
    values.map((v) => (Number.isFinite(v) ? Math.max(0, v) : 0));

  const symptoms = safe(symptomScores);
  const histories = safe(historyScores);

  const s = symptoms.length ? Math.max(...symptoms) : 0;
  const a = histories.length ? Math.max(...histories) : 0;
  const highSymptomCount = symptoms.filter((v) => v >= 2).length;

  const synergy = s >= 2 && a >= 2 ? 1 : 0;
  const accumulation = highSymptomCount >= 2 ? 1 : 0;

  const combined = Math.min(Math.max(s, a) + synergy + accumulation, 4);

  if (combined >= 3) return UrgencyLevel.HIGH;
  if (combined === 2) return UrgencyLevel.MEDIUM;
  return UrgencyLevel.LOW;
};
