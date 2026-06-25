import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Empreinte clinique déterministe d'une consultation **sans image**.
///
/// Deux consultations qui partagent la même empreinte ont la même signature
/// clinique discriminante (côté oreille, sexe, tranche d'âge, symptômes,
/// antécédents, vérifications au toucher) — donc une entrée équivalente pour le
/// modèle IA. On réutilise alors une réponse déjà obtenue au lieu de réinterroger
/// le modèle (déduplication serveur + cache hors-ligne).
///
/// Choix favorisant un **taux de réutilisation élevé** sans perte de sécurité :
///  - les **notes libres** sont EXCLUES (texte qui ne correspond quasi jamais à
///    l'identique) ;
///  - l'**âge** est ramené à une **tranche clinique** plutôt qu'à sa valeur exacte
///    (un 34 vs 35 ans ne doit pas rater), tout en gardant la distinction
///    pédiatrique/adulte qui, elle, change le diagnostic.
///
/// L'empreinte EXCLUT aussi toute donnée identifiante (nom, téléphone, adresse,
/// identifiant patient) : seule la signature clinique compte.
///
/// `fpv=` versionne l'algorithme : tout changement de schéma incrémente cette
/// valeur pour éviter qu'anciennes et nouvelles empreintes ne se confondent.
class ClinicalFingerprint {
  const ClinicalFingerprint._();

  /// Calcule l'empreinte (SHA-256 hex) à partir des caractéristiques cliniques.
  static String compute({
    required String earSide,
    String? sex,
    String? age,
    List<String> symptomIds = const [],
    List<String> medicalHistoryIds = const [],
    Map<String, String> touchObservations = const {},
  }) {
    final symptoms = _sortedUnique(symptomIds);
    final histories = _sortedUnique(medicalHistoryIds);

    final touchPairs = touchObservations.entries
        .map((e) => '${e.key.trim()}:${_norm(e.value)}')
        .toList()
      ..sort();

    final canonical = [
      'fpv=2',
      'ear=${_norm(earSide)}',
      'sex=${_norm(sex)}',
      'age=${_ageBucket(age)}',
      'sym=${symptoms.join(',')}',
      'hist=${histories.join(',')}',
      'touch=${touchPairs.join(',')}',
    ].join('|');

    return sha256.convert(utf8.encode(canonical)).toString();
  }

  /// Tranche d'âge clinique (ORL). Réduit les ratés dus à l'âge exact tout en
  /// préservant la frontière pédiatrique/adulte. Repli sur la valeur normalisée
  /// si l'âge n'est pas numérique.
  static String _ageBucket(String? age) {
    final years = _extractAge(age);
    if (years == null) return _norm(age);
    if (years <= 2) return '0-2';
    if (years <= 11) return '3-11';
    if (years <= 17) return '12-17';
    if (years <= 64) return '18-64';
    return '65+';
  }

  static int? _extractAge(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  /// Normalise : trim, minuscules, espaces internes compactés.
  static String _norm(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static List<String> _sortedUnique(List<String> ids) {
    final set = <String>{};
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) set.add(trimmed);
    }
    final list = set.toList()..sort();
    return list;
  }
}
