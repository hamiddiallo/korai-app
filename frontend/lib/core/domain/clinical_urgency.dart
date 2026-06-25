import 'korai_enums.dart';

/// Calcul du niveau d'urgence à partir des scores de danger (0–3) des symptômes
/// et antécédents sélectionnés.
///
/// ⚠️ Doit rester STRICTEMENT identique au calcul backend
/// (`backend/src/modules/consultations/urgency.ts`). Sert d'aperçu en direct et
/// de valeur provisoire pour les consultations enregistrées hors-ligne ; le
/// serveur reste l'autorité.
class ClinicalUrgency {
  const ClinicalUrgency._();

  static UrgencyLevel compute({
    required List<int> symptomScores,
    required List<int> historyScores,
  }) {
    int maxOf(List<int> v) =>
        v.isEmpty ? 0 : v.map((e) => e < 0 ? 0 : e).reduce((a, b) => a > b ? a : b);

    final s = maxOf(symptomScores);
    final a = maxOf(historyScores);
    final highSymptomCount = symptomScores.where((v) => v >= 2).length;

    final synergy = (s >= 2 && a >= 2) ? 1 : 0;
    final accumulation = (highSymptomCount >= 2) ? 1 : 0;

    var combined = (s > a ? s : a) + synergy + accumulation;
    if (combined > 4) combined = 4;

    if (combined >= 3) return UrgencyLevel.high;
    if (combined == 2) return UrgencyLevel.medium;
    return UrgencyLevel.low;
  }
}
