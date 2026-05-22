/// Valeurs alignées sur les enums Prisma du backend.
enum EarSide {
  left('LEFT'),
  right('RIGHT'),
  both('BOTH');

  const EarSide(this.value);
  final String value;

  static EarSide fromApi(String? raw) {
    return EarSide.values.firstWhere(
      (e) => e.value == raw?.toUpperCase(),
      orElse: () => EarSide.both,
    );
  }

  String get label => switch (this) {
        EarSide.left => 'Oreille gauche',
        EarSide.right => 'Oreille droite',
        EarSide.both => 'Les deux oreilles',
      };
}

enum ConsultationStatus {
  draft('DRAFT'),
  pendingAi('PENDING_AI'),
  aiCompleted('AI_COMPLETED'),
  pendingSpecialistReview('PENDING_SPECIALIST_REVIEW'),
  specialistCompleted('SPECIALIST_COMPLETED');

  const ConsultationStatus(this.value);
  final String value;

  static ConsultationStatus? tryFromApi(String? raw) {
    if (raw == null) return null;
    for (final status in ConsultationStatus.values) {
      if (status.value == raw) return status;
    }
    return null;
  }
}

enum UrgencyLevel {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH');

  const UrgencyLevel(this.value);
  final String value;
}

enum ClinicalReferenceType {
  symptom('SYMPTOM'),
  medicalHistory('MEDICAL_HISTORY'),
  touchCheck('TOUCH_CHECK');

  const ClinicalReferenceType(this.value);
  final String value;
}

enum ExpertiseStatus {
  pending('PENDING'),
  inReview('IN_REVIEW'),
  completed('COMPLETED');

  const ExpertiseStatus(this.value);
  final String value;

  static ExpertiseStatus? tryFromApi(String? raw) {
    if (raw == null) return null;
    for (final s in ExpertiseStatus.values) {
      if (s.value == raw) return s;
    }
    return null;
  }
}

enum ExpertDecision {
  validated('VALIDATED'),
  corrected('CORRECTED'),
  insufficient('INSUFFICIENT');

  const ExpertDecision(this.value);
  final String value;

  static ExpertDecision? tryFromApi(String? raw) {
    if (raw == null) return null;
    for (final d in ExpertDecision.values) {
      if (d.value == raw) return d;
    }
    return null;
  }

  String get label => switch (this) {
        ExpertDecision.validated => 'IA validée',
        ExpertDecision.corrected => 'Diagnostic corrigé',
        ExpertDecision.insufficient => 'IA insuffisante — avis substitut',
      };
}

enum EffectiveSummarySource {
  ai('AI'),
  expertValidated('EXPERT_VALIDATED'),
  expertCorrected('EXPERT_CORRECTED'),
  expertSubstitute('EXPERT_SUBSTITUTE');

  const EffectiveSummarySource(this.value);
  final String value;

  static EffectiveSummarySource? tryFromApi(String? raw) {
    if (raw == null) return null;
    for (final s in EffectiveSummarySource.values) {
      if (s.value == raw) return s;
    }
    return null;
  }

  String get badgeLabel => switch (this) {
        EffectiveSummarySource.ai => 'Analyse IA',
        EffectiveSummarySource.expertValidated => 'Validé par spécialiste',
        EffectiveSummarySource.expertCorrected => 'Corrigé par spécialiste',
        EffectiveSummarySource.expertSubstitute => 'Avis spécialiste',
      };
}

enum AiConfidenceLabel {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  unknown('UNKNOWN');

  const AiConfidenceLabel(this.value);
  final String value;

  static AiConfidenceLabel fromApi(String? raw) {
    return AiConfidenceLabel.values.firstWhere(
      (e) => e.value == (raw ?? 'UNKNOWN').toUpperCase(),
      orElse: () => AiConfidenceLabel.unknown,
    );
  }
}
