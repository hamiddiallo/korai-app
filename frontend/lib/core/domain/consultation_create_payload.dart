import 'dart:convert';

import 'korai_enums.dart';

/// Corps de requête pour `POST /cases/diagnose` (aligné backend).
class ConsultationCreatePayload {
  const ConsultationCreatePayload({
    required this.patientId,
    required this.symptoms,
    this.clinicalNotes,
    this.urgency = UrgencyLevel.medium,
    this.earSide = EarSide.both,
    this.showSources = true,
    this.requestSpecialistReview = false,
    this.symptomIds = const [],
    this.symptomLabels = const [],
    this.medicalHistoryIds = const [],
    this.medicalHistoryLabels = const [],
    this.touchCheckIds = const [],
    this.touchCheckLabels = const [],
    this.touchObservations = const {},
  });

  final String patientId;
  final String symptoms;
  final String? clinicalNotes;
  final UrgencyLevel urgency;
  final EarSide earSide;
  final bool showSources;
  final bool requestSpecialistReview;
  final List<String> symptomIds;
  final List<String> symptomLabels;
  final List<String> medicalHistoryIds;
  final List<String> medicalHistoryLabels;
  final List<String> touchCheckIds;
  final List<String> touchCheckLabels;
  final Map<String, String> touchObservations;

  Map<String, dynamic> toJsonBody() => {
        'patientId': patientId,
        'symptoms': symptoms,
        if (clinicalNotes != null && clinicalNotes!.isNotEmpty)
          'clinicalNotes': clinicalNotes,
        'urgency': urgency.value,
        'earSide': earSide.value,
        'showSources': showSources,
        'requestSpecialistReview': requestSpecialistReview,
        if (symptomIds.isNotEmpty) 'symptomIds': symptomIds,
        if (symptomLabels.isNotEmpty) 'symptomLabels': symptomLabels,
        if (medicalHistoryIds.isNotEmpty)
          'medicalHistoryIds': medicalHistoryIds,
        if (medicalHistoryLabels.isNotEmpty)
          'medicalHistoryLabels': medicalHistoryLabels,
        if (touchCheckIds.isNotEmpty) 'touchCheckIds': touchCheckIds,
        if (touchCheckLabels.isNotEmpty) 'touchCheckLabels': touchCheckLabels,
        if (touchObservations.isNotEmpty)
          'touchObservations': touchObservations,
      };

  /// Champs multipart : tableaux/objets encodés en JSON pour le parseur backend.
  Map<String, String> toMultipartFields() => {
        'patientId': patientId,
        'symptoms': symptoms,
        if (clinicalNotes != null && clinicalNotes!.isNotEmpty)
          'clinicalNotes': clinicalNotes!,
        'urgency': urgency.value,
        'earSide': earSide.value,
        'showSources': showSources.toString(),
        'requestSpecialistReview': requestSpecialistReview.toString(),
        if (symptomIds.isNotEmpty) 'symptomIds': jsonEncode(symptomIds),
        if (symptomLabels.isNotEmpty)
          'symptomLabels': jsonEncode(symptomLabels),
        if (medicalHistoryIds.isNotEmpty)
          'medicalHistoryIds': jsonEncode(medicalHistoryIds),
        if (medicalHistoryLabels.isNotEmpty)
          'medicalHistoryLabels': jsonEncode(medicalHistoryLabels),
        if (touchCheckIds.isNotEmpty)
          'touchCheckIds': jsonEncode(touchCheckIds),
        if (touchCheckLabels.isNotEmpty)
          'touchCheckLabels': jsonEncode(touchCheckLabels),
        if (touchObservations.isNotEmpty)
          'touchObservations': jsonEncode(touchObservations),
      };
}
