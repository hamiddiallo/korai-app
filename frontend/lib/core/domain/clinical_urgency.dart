import 'korai_enums.dart';

/// Calcul du niveau d'urgence à partir des scores de danger (0–3) du référentiel
/// clinique : signes de l'épisode (symptômes cochés + vérifications au toucher
/// anormales) et terrain (antécédents cochés).
///
/// ⚠️ Doit rester STRICTEMENT identique au calcul backend
/// (`backend/src/modules/consultations/urgency.ts`) : les deux sont vérifiés sur
/// les mêmes cas (`backend/test/fixtures/urgency-cases.json`). Sert d'aperçu en
/// direct et de valeur provisoire pour les consultations enregistrées hors
/// ligne ; le serveur reste l'autorité.
class ClinicalUrgency {
  const ClinicalUrgency._();

  static final _abnormal = RegExp(r'^\s*anormal', caseSensitive: false);

  static UrgencyLevel compute({
    required List<int> signScores,
    required List<int> historyScores,
  }) {
    List<int> safe(List<int> v) => [for (final e in v) e < 0 ? 0 : (e > 3 ? 3 : e)];
    int maxOf(List<int> v) => v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);

    final signs = safe(signScores);
    final s = maxOf(signs);
    final a = maxOf(safe(historyScores));
    final highSignCount = signs.where((v) => v >= 2).length;

    final synergy = (s >= 2 && a >= 2) ? 1 : 0;
    final accumulation = (highSignCount >= 2) ? 1 : 0;

    // Un antécédent seul plafonne à « moyen » : il aggrave un signe, il ne fait
    // pas une urgence à lui seul.
    final cappedHistory = a > 2 ? 2 : a;
    var combined = (s > cappedHistory ? s : cappedHistory) + synergy + accumulation;
    if (combined > 4) combined = 4;

    if (combined >= 3) return UrgencyLevel.high;
    if (combined == 2) return UrgencyLevel.medium;
    return UrgencyLevel.low;
  }

  /// Seul un résultat « Anormal — … » d'une vérification au toucher compte
  /// comme signe ; « Normal (négatif) » et « Non réalisé » ne comptent pas.
  static bool isAbnormalTouchFinding(String? observation) => observation != null && _abnormal.hasMatch(observation);
}
