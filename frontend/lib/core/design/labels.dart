import 'package:flutter/material.dart';

import '../domain/korai_enums.dart';
import 'korai_tokens.dart';

/// Libellés français des valeurs techniques renvoyées par l'API.
///
/// Aucune valeur brute (NURSE, HIGH, PENDING…) ne doit apparaître à l'écran :
/// tout passe par ces fonctions.
class KLabels {
  const KLabels._();

  static String role(String? raw) => switch (raw?.trim().toUpperCase()) {
        'NURSE' || 'PROFESSIONAL' => 'Infirmier·ère',
        'SPECIALIST' => 'Spécialiste ORL',
        'PATIENT' => 'Patient',
        'ADMIN' => 'Administrateur',
        _ => 'Rôle inconnu',
      };

  static String accountStatus(String? raw) =>
      switch (raw?.trim().toUpperCase()) {
        'ACTIVE' => 'Actif',
        'PENDING' => 'En attente de validation',
        'REJECTED' => 'Refusé',
        _ => 'Inconnu',
      };

  static KTone accountStatusTone(String? raw) =>
      switch (raw?.trim().toUpperCase()) {
        'ACTIVE' => KTone.success,
        'PENDING' => KTone.warning,
        'REJECTED' => KTone.danger,
        _ => KTone.neutral,
      };

  static String sex(String? raw) => switch (raw?.trim().toUpperCase()) {
        'M' || 'MALE' || 'H' => 'Masculin',
        'F' || 'FEMALE' => 'Féminin',
        _ => 'Non renseigné',
      };

  /// Sexe pour une ligne de résumé : `null` s'il n'est pas renseigné (on
  /// l'omet plutôt que d'afficher « Non renseigné » sans contexte).
  static String? sexOrNull(String? raw) {
    final label = sex(raw);
    return label == 'Non renseigné' ? null : label;
  }

  // ---------------- Consultations ----------------

  static String consultationStatus(String? raw) =>
      switch (ConsultationStatus.tryFromApi(raw)) {
        ConsultationStatus.draft => 'Brouillon',
        ConsultationStatus.pendingAi => 'Analyse en cours',
        ConsultationStatus.aiFailed => 'Analyse à relancer',
        ConsultationStatus.aiCompleted => 'Analyse terminée',
        ConsultationStatus.pendingSpecialistReview => 'En attente d’avis',
        ConsultationStatus.specialistCompleted => 'Avis reçu',
        null => 'Statut inconnu',
      };

  static KTone consultationStatusTone(String? raw) =>
      switch (ConsultationStatus.tryFromApi(raw)) {
        ConsultationStatus.draft => KTone.neutral,
        ConsultationStatus.pendingAi => KTone.info,
        ConsultationStatus.aiFailed => KTone.warning,
        ConsultationStatus.aiCompleted => KTone.ai,
        ConsultationStatus.pendingSpecialistReview => KTone.neutral,
        ConsultationStatus.specialistCompleted => KTone.success,
        null => KTone.neutral,
      };

  static IconData consultationStatusIcon(String? raw) =>
      switch (ConsultationStatus.tryFromApi(raw)) {
        ConsultationStatus.draft => Icons.edit_note_rounded,
        ConsultationStatus.pendingAi => Icons.hourglass_top_rounded,
        ConsultationStatus.aiFailed => Icons.refresh_rounded,
        ConsultationStatus.aiCompleted => Icons.auto_awesome_rounded,
        ConsultationStatus.pendingSpecialistReview => Icons.schedule_rounded,
        ConsultationStatus.specialistCompleted => Icons.verified_rounded,
        null => Icons.help_outline_rounded,
      };

  // ---------------- Expertise ----------------

  static String expertiseStatus(String? raw) =>
      switch (ExpertiseStatus.tryFromApi(raw)) {
        ExpertiseStatus.pending => 'En attente',
        ExpertiseStatus.inReview => 'Pris en charge',
        ExpertiseStatus.completed => 'Terminée',
        null => 'Statut inconnu',
      };

  static KTone expertiseStatusTone(String? raw) =>
      switch (ExpertiseStatus.tryFromApi(raw)) {
        ExpertiseStatus.pending => KTone.warning,
        ExpertiseStatus.inReview => KTone.brand,
        ExpertiseStatus.completed => KTone.success,
        null => KTone.neutral,
      };

  static String expertDecision(String? raw) =>
      ExpertDecision.tryFromApi(raw)?.label ?? 'Décision non précisée';

  // ---------------- IA ----------------

  static String confidence(String? raw) =>
      switch (AiConfidenceLabel.fromApi(raw)) {
        AiConfidenceLabel.low => 'faible',
        AiConfidenceLabel.medium => 'moyenne',
        AiConfidenceLabel.high => 'élevée',
        AiConfidenceLabel.unknown => 'non précisée',
      };

  /// « élevée · 82 % » à partir du libellé et du score (0–1 ou 0–100).
  static String confidenceWithScore(String? raw, num? score) {
    final label = confidence(raw);
    if (score == null) return label;
    final pct = score <= 1 ? (score * 100).round() : score.round();
    return '$label · $pct %';
  }

  // ---------------- Oreille ----------------

  /// Symbole de l'audiogramme : ○ droite, × gauche.
  static String earMark(EarSide side) => switch (side) {
        EarSide.right => '○',
        EarSide.left => '×',
        EarSide.both => '○×',
      };

  static String earShort(EarSide side) => switch (side) {
        EarSide.right => 'droite',
        EarSide.left => 'gauche',
        EarSide.both => 'deux oreilles',
      };

  /// « ○ Oreille droite ».
  static String earWithMark(EarSide side) => '${earMark(side)} ${side.label}';
}
