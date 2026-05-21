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
